#include <vector>
#include <string>

#include <cget/cmake-utils.h>

namespace cget {
  namespace github {

    CMakeProjectDesc GetCMakeDesc(const std::string& repoPath);
  
    struct RepoInfo {
      size_t id;
      std::string name;
      std::string fullname;
      std::string url;
      size_t stars;
      std::string desc;
    };

    std::string LatestVersionByName(const std::string& name); 
    std::vector<RepoInfo> SearchByName(const std::string& name, const std::vector<std::string>& langs, bool exactNameMatch = false);
    std::vector<RepoInfo> GetCandidates(const std::string& name, const std::vector<std::string>& langs); 
    RepoInfo Get(const std::string& name);
  }
}
