// Minimal stub of gtest/gtest_prod.h for iOS builds with BUILD_TESTING=OFF.
// Mixxx production headers use FRIEND_TEST; only the macro is required to compile.
#pragma once
#ifndef FRIEND_TEST
#define FRIEND_TEST(test_case_name, test_name) \
    friend class test_case_name##_##test_name##_Test
#endif
