load("@bazel_skylib//lib:collections.bzl", "collections")
load("//java/private:package.bzl", "get_class_name")

def _is_test(src, test_suffixes, test_suffixes_excludes):
    for suffix in test_suffixes:
        if src.endswith(suffix):
            for suffix_exclude in test_suffixes_excludes:
                if src.endswith(suffix_exclude):
                    return False
            return True
    return False

_LIBRARY_ATTRS = [
    "data",
    "javacopts",
    "plugins",
    "resources",
]

def create_jvm_test_suite(
        name,
        srcs,
        test_suffixes,
        package,
        define_library,
        define_test,
        library_attributes = _LIBRARY_ATTRS,
        deps = None,
        runtime_deps = [],
        tags = [],
        visibility = None,
        size = None,
        package_prefixes = [],
        test_suffixes_excludes = [],
        **kwargs):
    """Generate a test suite for rules that "feel" like `java_test`.

    Given the list of `srcs`, this macro will generate:

      1. A `*_test` target per `src` that matches any of the `test_suffixes`
      2. A shared library that these tests depend on for any non-test `srcs`
      3. A `test_suite` tagged as `manual` that aggregates all the tests

    The reason for having a test target per test source file is to allow for
    better parallelization. Initial builds may be slower, but iterative builds
    while working with on unit tests should be faster, and this approach
    makes best use of the RBE.

    Args:
      name: The name of the generated test suite.
      srcs: A list of source files.
      test_suffixes: A list of suffixes (eg. `["Test.kt"]`)
      test_suffixes_excludes: A list of suffix excludes (eg. `["BaseTest.kt"]`)
      package: The package name to use. If `None`, a value will be
        calculated from the bazel package.
      library_attributes: Attributes to pass to `define_library`.
      define_library: A function that creates a `*_library` target.
      define_test: A function that creates a `*_test` target and returns the name of the created target.
        (See java/test/com/github/bazel_contrib/contrib_rules_jvm/junit5/suite_tags for example use)
      deps: The list of dependencies to use when compiling.
      runtime_deps: The list of runtime deps to use when running tests.
      tags: Tags to use for generated targets.
      size: Bazel test size
    """

    # First, grab any interesting attrs
    library_attrs = {attr: kwargs[attr] for attr in library_attributes if attr in kwargs}

    test_srcs = [src for src in srcs if _is_test(src, test_suffixes, test_suffixes_excludes)]
    nontest_srcs = [src for src in srcs if not _is_test(src, test_suffixes, test_suffixes_excludes)]

    if nontest_srcs:
        lib_dep_name = "%s-test-lib" % name
        lib_dep_label = ":%s" % lib_dep_name
        deps_for_library = [dep for dep in deps or [] if _absolutify(dep) != _absolutify(lib_dep_label)]

        # Build a shared test library to use for everything. If we don't do this,
        # each rule needs to compile all sources, and that seems grossly inefficient.
        # Only include the non-test sources since we don't want all tests to re-run
        # when only one test source changes.
        define_library(
            name = lib_dep_name,
            deps = deps_for_library,
            srcs = nontest_srcs,
            testonly = True,
            visibility = visibility,
            tags = tags,
            **library_attrs
        )
        if not _contains_label(deps or [], lib_dep_label):
            deps = deps + [lib_dep_label]

    tests = []

    # Optimization for classpath, reduces the duplicate dependencies for each test to instead rely on one target
    deps_lib_name = "%s-test-deps-lib" % name
    define_library(
        name = deps_lib_name,
        exports = deps,
        visibility = ["//visibility:private"],
        tags = tags,
        testonly = True,
        **library_attrs
    )
    runtime_deps_lib_name = "%s-test-runtime-deps-lib" % name
    define_library(
        name = runtime_deps_lib_name,
        exports = runtime_deps,
        visibility = ["//visibility:private"],
        tags = tags,
        testonly = True,
        **library_attrs
    )

    # Get any deps referenced in make vars
    make_var_fields = (kwargs.get("jvm_flags", []) +
                       kwargs.get("javacopts", []) +
                       kwargs.get("args", []) +
                       kwargs.get("env", {}).values())
    make_var_deps = collections.uniq([dep for dep in deps for flag in make_var_fields if dep in flag])
    make_var_runtime_deps = collections.uniq([dep for dep in runtime_deps for flag in make_var_fields if dep in flag])

    for src in test_srcs:
        suffix = src.rfind(".")
        test_name = src[:suffix]
        test_class = get_class_name(package, src, package_prefixes)

        test_name = define_test(
            name = test_name,
            size = size,
            srcs = [src],
            test_class = test_class,
            deps = [":" + deps_lib_name] + make_var_deps,
            tags = tags,
            runtime_deps = [":" + runtime_deps_lib_name] + make_var_runtime_deps,
            visibility = ["//visibility:private"],
            **kwargs
        )
        tests.append(test_name)

    native.test_suite(
        name = name,
        tests = tests,
        tags = ["manual"] + tags,
        visibility = visibility,
    )

def _contains_label(haystack_str_list, needle):
    absolute_needle = _absolutify(needle)
    for haystack_str in haystack_str_list or []:
        absolute_haystack_label = _absolutify(haystack_str)
        if absolute_needle == absolute_haystack_label:
            return True
    return False

def _absolutify(label_str):
    repo = ""
    package = ""
    name = ""

    if label_str.startswith("@"):
        parts = label_str.split("//")
        repo = parts[0][1:]

    if "//" in label_str:
        parts = label_str.split("//")
        package = parts[1].split(":")[0]
    else:
        package = native.package_name()

    if ":" in label_str:
        name = label_str.split(":")[1]
    else:
        name = package.split("/")[-1]

    return "@{}//{}:{}".format(repo, package, name)
