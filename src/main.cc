#include <cget/utilities.h>
#include <iostream>
#include <map>

#include "config.h"
#include "main-init.h"
#include "main-install.h"

typedef int (*main_fn)(int argc, char** argv);


std::map<std::string, main_fn> handlers =
  {
    {"init", main_init},
    {"install", main_install}
  };

static void printUsage() {
  std::cout << "cget version " CGET_VERSION << std::endl << std::endl; 
  std::cout << "Available built-in commands: " << std::endl;
  for(auto& cmd : handlers) {
    if(cmd.second)
      std::cout << "    * " << cmd.first << std::endl;
  }
}
static int exitWith(int rtn) {
  if(rtn != 0) 
    printUsage();
  return rtn; 
}

int main(int argc, char* argv[]) {
  if(argc <= 1)
    return exitWith(-1);
  auto rtn = -1; 
  main_fn fn = handlers[argv[1]];  
  if(fn == 0) {
    std::cout << "Unknown option '" << argv[1] << "'" << std::endl;
    return exitWith(-1);
  }

  return exitWith(fn(argc, argv)); 
}
