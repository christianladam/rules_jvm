"""Unit tests for generated target names."""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("//java/private:naming.bzl", "generated_name", "join_name")

def _join_name_test_impl(ctx):
    env = unittest.begin(ctx)
    asserts.equals(env, "foo-test-lib", join_name("-", "foo", "test", "lib"))
    asserts.equals(env, "foo_test_lib", join_name("_", "foo", "test", "lib"))
    asserts.equals(env, "foo_checkstyle", join_name("_", "foo", "checkstyle"))
    return unittest.end(env)

_join_name_test = unittest.make(_join_name_test_impl)

def _generated_name_defaults_to_hyphen_test_impl(ctx):
    env = unittest.begin(ctx)

    # This repository doesn't configure the `naming` extension, so it gets the default.
    asserts.equals(env, "foo-test-runtime-deps-lib", generated_name("foo", "test", "runtime", "deps", "lib"))
    return unittest.end(env)

_generated_name_defaults_to_hyphen_test = unittest.make(_generated_name_defaults_to_hyphen_test_impl)

def naming_test_suite(name):
    unittest.suite(
        name,
        _join_name_test,
        _generated_name_defaults_to_hyphen_test,
    )
