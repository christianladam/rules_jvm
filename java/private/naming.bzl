"""Builds the names of the targets contrib_rules_jvm's macros generate."""

load("@contrib_rules_jvm_naming//:naming.bzl", "SEPARATOR")

def join_name(separator, name, *words):
    """Joins `name` and `words` with `separator`. Split out of `generated_name` for testing."""
    return separator.join([name] + list(words))

def generated_name(name, *words):
    """Returns the name of a target generated for `name`, e.g. `foo-test-lib` or `foo_test_lib`.

    Args:
      name: The name of the target the macro was called with.
      *words: The words to add, e.g. `"test", "lib"`.

    Returns:
      The generated target's name, using the separator chosen with the `naming` extension.
    """
    return join_name(SEPARATOR, name, *words)
