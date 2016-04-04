defmodule Gettext.PO.Translations do
  @moduledoc false

  alias Gettext.PO.Translation
  alias Gettext.PO.PluralTranslation

  defmacrop is_translation(module) do
    quote do
      unquote(module) in [Translation, PluralTranslation]
    end
  end

  @doc """
  Tells whether a translation was manually entered or generated by Gettext.

  As of now, a translation is considered autogenerated if it has one or more
  references.

  ## Examples

      iex> t = %Gettext.PO.Translation{msgid: "foo", references: [{"foo.ex", 1}]}
      iex> Gettext.PO.Translations.autogenerated?(t)
      true

  """
  @spec autogenerated?(Gettext.PO.translation) :: boolean
  def autogenerated?(translation)

  def autogenerated?(%{__struct__: s, references: []})
    when is_translation(s),
    do: false
  def autogenerated?(%{__struct__: s, references: _})
    when is_translation(s),
    do: true

  @doc """
  Tells whether a translation is protected from purging.

  A translation that is protected from purging will never be removed by Gettext.
  Which translations are proteced can be configured using Mix.

  ## Example

      config :gettext,
        exlude_refs_from_pruging: "^web\/static\/.*"
  """
  @spec protected?(Gettext.PO.translation) :: boolean
  def protected?(%{__struct__: s, msgid: msgid, references: []}) when is_translation(s), do: false

  def protected?(%{__struct__: s, msgid: msgid, references: refs}) when is_translation(s) do
    {:ok, pattern} = Application.get_env(:gettext, :excluded_refs_from_purging, "(?!x)x")
    |> Regex.compile
    refs
    |> Enum.map(fn({line, _}) -> line end)
    |> Enum.any?(&Regex.match?(pattern, &1))
  end

  @doc """
  Tells whether two translations are the same translation according to their
  `msgid`.

  This function returns `true` if `translation1` and `translation2` are the same
  translation, where "the same" means they have the same `msgid` or the same
  `msgid` and `msgid_plural`.

  ## Examples

      iex> t1 = %Gettext.PO.Translation{msgid: "foo", references: [{"foo.ex", 1}]}
      iex> t2 = %Gettext.PO.Translation{msgid: "foo", comments: ["# hey"]}
      iex> Gettext.PO.Translations.same?(t1, t2)
      true

  """
  @spec same?(Gettext.PO.translation, Gettext.PO.translation) :: boolean
  def same?(translation1, translation2) do
    key(translation1) == key(translation2)
  end

  @doc """
  Returns a "key" that can be used to identify a translation.

  This function returns a "key" that can be used to uniquely identify a
  translation assuming that no "same" translations exist; for what "same"
  means, look at the documentation for `same?/2`.

  The purpose of this function is to be used in situations where we'd like to
  group or sort translations but where we don't need the whole structs.

  ## Examples

      iex> t = %Gettext.PO.Translation{msgid: "foo"}
      iex> Gettext.PO.Translations.key(t)
      "foo"

      iex> t = %Gettext.PO.PluralTranslation{msgid: "foo", msgid_plural: "foos"}
      iex> Gettext.PO.Translations.key(t)
      {"foo", "foos"}

  """
  @spec key(Gettext.PO.Translation.t) :: binary
  @spec key(Gettext.PO.PluralTranslation.t) :: {binary, binary}
  def key(%Translation{msgid: msgid}),
    do: IO.iodata_to_binary(msgid)
  def key(%PluralTranslation{msgid: msgid, msgid_plural: msgid_plural}),
    do: {IO.iodata_to_binary(msgid), IO.iodata_to_binary(msgid_plural)}

  @doc """
  Finds a given translation in a list of translations.

  Equality between translations is checked using `same?/2`.
  """
  @spec find([Translation.t | PluralTranslation.t], Translation.t) :: nil | Translation.t
  @spec find([Translation.t | PluralTranslation.t], PluralTranslation.t) :: nil | PluralTranslation.t
  def find(translations, %{__struct__: s} = target)
      when is_list(translations) and is_translation(s) do
    Enum.find(translations, &same?(&1, target))
  end

  @doc """
  Marks the given translation as "fuzzy".

  This function just adds the `"fuzzy"` flag to the `:flags` field of the given
  translation.
  """
  @spec mark_as_fuzzy(Translation.t) :: Translation.t
  @spec mark_as_fuzzy(PluralTranslation.t) :: PluralTranslation.t
  def mark_as_fuzzy(%{__struct__: s, flags: flags} = t) when is_translation(s) do
    %{t | flags: MapSet.put(flags, "fuzzy")}
  end
end
