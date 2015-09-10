defmodule Mix.Tasks.Gettext.MergeTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  @priv_path "../../../tmp/gettext.merge" |> Path.expand(__DIR__) |> Path.relative_to_cwd

  setup do
    File.rm_rf!(@priv_path)
    :ok
  end

  test "merging an existing PO file with a new POT file" do
    # "No such file" errors if one of the files doesn't exist.
    assert_raise Mix.Error, "No such file: foo.po", fn ->
      run ~w(foo.po bar.pot)
    end

    # The first file must be be a .po file and the second one a .pot file.
    assert_raise Mix.Error, "Arguments must be a PO file and a POT file", fn ->
      run ~w(foo.ex bar.exs)
    end

    pot_contents = """
    msgid "hello"
    msgstr ""
    """
    write_file "foo.pot", pot_contents

    write_file "it/LC_MESSAGES/foo.po", ""

    output = capture_io fn ->
      run [tmp_path("it/LC_MESSAGES/foo.po"), tmp_path("foo.pot")]
    end

    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/foo.po"

    # The POT file is left unchanged
    assert read_file("foo.pot") == pot_contents

    assert read_file("it/LC_MESSAGES/foo.po") == """
    msgid "hello"
    msgstr ""
    """
  end

  test "passing a dir and a --locale opt will update/create PO files in the locale dir" do
    write_file "default.pot", """
    msgid "def"
    msgstr ""
    """

    write_file "new.pot", """
    msgid "new"
    msgstr ""
    """

    write_file "it/LC_MESSAGES/default.po", ""

    output = capture_io fn ->
      run [@priv_path, "--locale", "it"]
    end

    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/new.po"
    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/default.po"

    assert read_file("it/LC_MESSAGES/default.po") == """
    msgid "def"
    msgstr ""
    """

    assert read_file("it/LC_MESSAGES/new.po") == ~S"""
    msgid ""
    msgstr ""
    "Language: it\n"

    msgid "new"
    msgstr ""
    """
  end

  test "passing just a dir merges with PO files in every locale" do
    write_file "fr/LC_MESSAGES/foo.po", ""
    write_file "it/LC_MESSAGES/foo.po", ""

    contents = """
    msgid "foo"
    msgstr ""
    """

    write_file "foo.pot", contents

    output = capture_io fn ->
      run [@priv_path]
    end

    assert output =~ "Wrote tmp/gettext.merge/fr/LC_MESSAGES/foo.po"
    assert output =~ "Wrote tmp/gettext.merge/it/LC_MESSAGES/foo.po"

    assert read_file("fr/LC_MESSAGES/foo.po") == contents
    assert read_file("it/LC_MESSAGES/foo.po") == contents
  end

  test "passing more than one argument raises an error" do
    msg = "Too many arguments for the gettext.merge task. Use " <>
          "`mix help gettext.merge` to see the usage of this task."
    assert_raise Mix.Error, msg, fn ->
      run ~w(foo bar baz bong)
    end
  end

  defp write_file(path, contents) do
    path = tmp_path(path)
    File.mkdir_p! Path.dirname(path)
    File.write!(path, contents)
  end

  defp read_file(path) do
    path |> tmp_path() |> File.read!()
  end

  defp tmp_path(path) do
    Path.join(@priv_path, path)
  end

  defp run(args) do
    Mix.Tasks.Gettext.Merge.run(args)
  end
end
