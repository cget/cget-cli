#pragma once

#include <vector>
#include <string>

struct CMakeProjectDesc {
  std::string name;
  std::vector<std::string> languages; 
};

CMakeProjectDesc cmake_get_desc(const std::string& dir = ".");
CMakeProjectDesc cmake_get_desc(std::istream& cmakelists);
