#include <string>

namespace cget {
  
  struct RepoSource {
    enum t {
      UNKNOWN,
      GITHUB,
      GIT,
      HG,
      SVN,
      URL,
      REGISTRY
    };
    static std::string ToString(t);
  };

  struct RepoMetadata {
    std::string name;
    RepoSource::t source;
    std::string url;
    std::string version;
  };

  void insert_hook();
  void init_project();
  void insert(const RepoMetadata& meta);
  RepoMetadata getMetaData(const std::string& id);
 
}
