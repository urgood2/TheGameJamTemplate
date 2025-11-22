#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <string>

#include "systems/scripting/binding_recorder.hpp"

TEST(BindingRecorder, WritesDefinitionsForTypesAndModules)
{
    auto &rec = BindingRecorder::instance();
    rec.set_module_name("test_module");
    rec.set_module_version("1.2.3");
    rec.set_module_doc("Test module docs");

    auto &type = rec.add_type("TestType");
    type.doc = "A simple test type";
    rec.record_property("TestType", {"VALUE", "number", "example property"});
    rec.record_method("TestType",
                      {"doThing",
                       "---@param x number\n---@return number",
                       "Does a thing",
                       false,
                       false});

    rec.record_free_function({"sub", "module"},
                             {"do_free",
                              "---@param s string",
                              "nested free function",
                              true,
                              false});

    const auto outputPath = std::filesystem::temp_directory_path() / "binding_recorder_test.lua";
    rec.dump_lua_defs(outputPath.string());

    std::ifstream in(outputPath);
    ASSERT_TRUE(in.is_open());
    std::string contents((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    in.close();
    std::filesystem::remove(outputPath);

    EXPECT_NE(contents.find("---@class TestType"), std::string::npos);
    EXPECT_NE(contents.find("doThing"), std::string::npos);
    EXPECT_NE(contents.find("sub.module.do_free"), std::string::npos);
    EXPECT_NE(contents.find("version: 1.2.3"), std::string::npos);
    EXPECT_NE(contents.find("Test module docs"), std::string::npos);
}
