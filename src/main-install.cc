#include <iostream>
#include <cget/utilities.h>
#include <cget/github-search.h>
#include <cget/cmake-utils.h>
#include <algorithm>
#include <string>
#include <sstream>
#include <memory>
#include <regex>

using namespace std::regex_constants;

static std::regex specific_github("^\\w+/\\w+$", ECMAScript | icase);
static std::regex search_term("^\\w+$", ECMAScript | icase);
static std::regex git_repo("^.*/([\\w\\.]+)/?\\.git/?$", ECMAScript | icase);
static std::regex hg_repo("^.*(\\w*)\\\\?\\.hg$", ECMAScript | icase);
static std::regex svn_repo("^svn://.*/(\\w*)/?$", ECMAScript | icase);
static std::regex url("^.*(\\w*)[\\.tar(\\.gz)?|\\.zip]$", ECMAScript | icase);

using namespace cget;
using namespace cget::github; 

std::string toLower(const std::string& data) {
  std::string rtn = data;
  std::transform(rtn.begin(), rtn.end(), rtn.begin(), ::tolower);
  return rtn;
}


static std::shared_ptr<RepoInfo> choose_repo(const std::string& target,
					      const std::vector<RepoInfo>& repos) {
  
  if(repos.size() == 0)
    return 0;

  bool hasExactMatch = toLower(repos[0].name) == target ||
    toLower(repos[0].name) == target + ".cget";

  if(repos.size() == 1 && hasExactMatch)
    return std::make_shared<RepoInfo>(repos[0]);
  
  if(hasExactMatch && toLower(repos[1].name) != target)
    return std::make_shared<RepoInfo>(repos[0]); 

  std::vector<RepoInfo> display_repos(repos.size()); 
  if(hasExactMatch) {    
    auto it = std::copy_if(repos.begin(), repos.end(), display_repos.begin(),
		 [&target](const RepoInfo& info) {
		   return toLower(info.name) == target;
		 });
    display_repos.resize(std::distance(display_repos.begin(),it));  // shrink container to new size   
  } else {
    display_repos = repos; 
  }

  size_t nameSize = 1;
  for(int i = 0;i < display_repos.size();i++) {
    nameSize = std::max(nameSize, display_repos[i].fullname.size()); 
  }
  
  for(int i = 0;i < display_repos.size();i++) {
    auto& info = display_repos[i];
    printf("[%2d] %-*s - (%d) %s\n", i+1, nameSize, info.fullname.c_str(), info.stars, info.desc.c_str());
  }

  std::cout << "Choose 1-" << display_repos.size() << " [1] "; 
  int choice = 0;
  std::string response;
  std::getline(std::cin, response);
  std::stringstream ss(response);
  ss >> choice;
  choice--;
  if(choice < 0) choice = 0; 
  return std::make_shared<RepoInfo>(display_repos[choice]);
}


static RepoMetadata ParseTermGetRepo(const std::string& target, const std::vector<std::string>& langs) {
  std::smatch m;

  std::vector<RepoInfo> repos; 
  if( std::regex_search(target, m, specific_github) ) {
    repos.push_back( Get(target) );
  } else if( std::regex_search(target, m, search_term) ) {
    repos = GetCandidates(target, langs);
  }

  if(repos.size()) {    
    auto choice = choose_repo(target, repos);
    if(choice) {
      auto cmake_desc = GetCMakeDesc(choice->fullname);
      std::string name = choice->name;
      if(cmake_desc.name != "") {
	name = cmake_desc.name;
      } else {
	std::cout << "Warning -- could not find proper cmake project name for package, basing it off of github path" << std::endl;      
      }
      bool isInRegistry = choice->fullname == "cget/" + name;
      return (RepoMetadata) {
	name,
	  isInRegistry ? RepoSource::REGISTRY : RepoSource::GITHUB,
	  choice->fullname,
	  LatestVersionByName(choice->fullname)
      };
    }    
  }

  auto repo_types = {
    std::make_pair(hg_repo, RepoSource::HG),
    std::make_pair(svn_repo, RepoSource::SVN),
    std::make_pair(git_repo, RepoSource::GIT),
    std::make_pair(url, RepoSource::URL)
    };
  
  for(auto check : repo_types ) {
    std::cout << "Trying regex..." << std::endl;
    if( std::regex_search(target, m, check.first) ) {
      std::cout << "regex matched... " << m.str() << " " << m[0] << " " << m[1] << std::endl;

      std::string version = "";
      switch(check.second) {
      case RepoSource::GIT: version = "master"; break;
      case RepoSource::HG: version = "tip"; break;
      default: break;
      }
      
      return (RepoMetadata) {
	m[1],
	  check.second,
	  target,
	  version,
	  };
    }
  }
  
  return RepoMetadata(); 
}

int main_install(int argc, char* argv[]) {
  if(argc <= 2) {
    std::cout << "Install command requires package name" << std::endl  << std::endl;
    return -1; 
  }
  std::string target = argv[2];
  auto desc = cmake_get_desc();
  auto repo = ParseTermGetRepo(target, desc.languages);
  if(repo.name.size()) {
    insert(repo);
  } else {
    std::cerr << "Error: couldn't find an installation candidate for '" << target << "'" << std::endl;
  }
  return 0; 
}
