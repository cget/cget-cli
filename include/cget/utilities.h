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

    std::string FullUrl() const;
  };

  void insert_hook();
  void init_project();
  void submodule_add_if_not_exist(const std::string& url,
				  const std::string& path);
  
  void insert(const RepoMetadata& meta, const std::string& subrepo_loc = "");
  RepoMetadata getMetaData(const std::string& id);
 
}
