#include <cget/cmake-utils.h>
#include <fstream>
#include <regex>
#include <iostream>

#define ANY_WS "[ \t]*"
#define LPAREN "\\("
#define RPAREN "\\)"

using namespace std::regex_constants;
static std::string project_match_reg = "project" ANY_WS LPAREN ANY_WS "(\\w+)" ANY_WS "(.*)" RPAREN; 
static std::regex project_match(project_match_reg, ECMAScript | icase );
// \\w*\\(\\w*\\)");

static std::string toLower(const std::string& data) {
  std::string rtn = data;
  std::transform(rtn.begin(), rtn.end(), rtn.begin(), ::tolower);
  return rtn;
}
CMakeProjectDesc cmake_get_desc(std::istream& cmakelists) {
  std::string projLine = "";
  std::smatch m;

  CMakeProjectDesc rtn;
  
  while(std::getline(cmakelists, projLine)) {
    if( std::regex_search(projLine, m, project_match) ) {
      if(m.size() == 1) break;
      rtn.name = m[1];

      if(m.size() == 2) break;
      std::string languages = m[2];
      char* token = strtok(&languages[0], " ");
      do {
	if(token[0] == '\0') continue;
	std::string lang = toLower(token);
	if(lang == "cxx")
	  lang = "c++";
	
	rtn.languages.push_back(lang); 
      } while (token = strtok(0, " ")); 
      
      break;
    }
  }

  return rtn; 
}
CMakeProjectDesc cmake_get_desc(const std::string& dir) {
  std::ifstream cmakelist(dir + "/CMakeLists.txt");
  return cmake_get_desc(cmakelist);
}
