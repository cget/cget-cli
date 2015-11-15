#include "rapidjson/document.h"
#include "rapidjson/writer.h"
#include "rapidjson/stringbuffer.h"
#include "rapidjson/error/en.h"

#include <sstream>
#include <fstream>
#include <iostream>
#include <cget/github-search.h>
#include <cget/cmake-utils.h>
#include <curl/multi.h>
#include <vector>
#include <cstring>

using namespace rapidjson;


namespace cget {
  namespace github {

    class curl_handle {
      CURL* handle;
      curl_handle();
      ~curl_handle();

    public:
      std::vector<uint8_t> buffer; 
      size_t OnRecv(void* contents, size_t size);
      std::string Escape(const std::string& str);
      std::vector<uint8_t>& Get(const std::string& url);
      rapidjson::Document* GetJSON(const std::string& url); 
      static curl_handle instance; 
    };

    curl_handle curl_handle::instance;

    curl_handle::~curl_handle() {
      curl_easy_cleanup(handle);
      handle = 0; 
    }

    static size_t _onrecv (void *contents, size_t size, size_t nmemb, void *user) {
      curl_handle* _this = (curl_handle*)user;
      return _this->OnRecv(contents, size * nmemb);
    }
    size_t curl_handle::OnRecv(void* contents, size_t size) {
      buffer.insert(buffer.end(), (uint8_t*)contents, (uint8_t*)contents+size);
      return size; 
    }
    std::string curl_handle::Escape(const std::string& str) {
      char* _q = curl_easy_escape(curl_handle::instance.handle, str.c_str(), str.size() );
      std::string q = _q;
      curl_free(_q);
      return q; 
    }
    std::vector<uint8_t>& curl_handle::Get(const std::string& url) {    
      curl_easy_setopt(handle, CURLOPT_URL, url.c_str());
      buffer.clear();
  
      auto res = curl_easy_perform(handle);
      if(res != CURLE_OK) {
	fprintf(stderr, "curl_easy_perform() failed: %s\n",
		curl_easy_strerror(res));
      } 
      return buffer; 
    }
    rapidjson::Document* curl_handle::GetJSON(const std::string& url) {
      auto& buffer = Get(url); 

      if(buffer.size() == 0)
	return 0;
  
      rapidjson::Document *rtn  = new rapidjson::Document();
      rtn->Parse<rapidjson::kParseStopWhenDoneFlag>((char*)&buffer[0]);   
      return rtn;
    }
    curl_handle::curl_handle() {
      handle = curl_easy_init();
      curl_easy_setopt(handle, CURLOPT_WRITEDATA, (void *)this);
      curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, _onrecv);
      curl_easy_setopt(handle, CURLOPT_FOLLOWLOCATION, 1L);
      /* SSL Options */
      curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER , 0);
      curl_easy_setopt(handle, CURLOPT_SSL_VERIFYHOST , 0);
      /* Provide CA Certs from http://curl.haxx.se/docs/caextract.html */
      //curl_easy_setopt(handle, CURLOPT_CAINFO, "ca-bundle.crt");
      curl_easy_setopt(handle, CURLOPT_HEADER, 0L);
      //curl_easy_setopt(handle, CURLOPT_URL, urls[i]);
      //curl_easy_setopt(handle, CURLOPT_PRIVATE, urls[i]);
      curl_easy_setopt(handle, CURLOPT_VERBOSE, 0L);
      curl_easy_setopt(handle, CURLOPT_USERAGENT, "cget");
    }

#define RAPID_JSON_TYPE(value, name, type, def) value.HasMember(name) ? (value[name].Is##type() ? value[name].Get##type() : def) : def

    RepoInfo Populate(Value& item) {
      RepoInfo info;  
      info.name = RAPID_JSON_TYPE(item, "name", String, ""); 
      info.fullname = RAPID_JSON_TYPE(item,"full_name", String, "");
      info.url = RAPID_JSON_TYPE(item,"url", String, "");
      info.id  = RAPID_JSON_TYPE(item,"id", Int, -1);
      info.desc = RAPID_JSON_TYPE(item,"description", String, "");
      info.stars = RAPID_JSON_TYPE(item,"stargazers_count", Int, -1);
      return info; 
    }

    static void add_to_list(std::vector<RepoInfo>& infos, Value& item) {
      infos.push_back(Populate(item));
    }

    CMakeProjectDesc GetCMakeDesc(const std::string& repoPath) {
      std::stringstream str;
      std::string url = "https://raw.githubusercontent.com/" + repoPath + "/master/CMakeLists.txt";
  
      auto& b = curl_handle::instance.Get(url);
      str.write((const char*)&b[0], b.size());
      return cmake_get_desc(str); 
    }
    std::vector<RepoInfo> GetCandidates(const std::string& name, const std::vector<std::string>& langs) {
      std::vector<RepoInfo> infos;

      RepoInfo blessed_repo = Get("cget/" + name + ".cget");
      if(blessed_repo.name != "") {
	infos.push_back(blessed_repo);
	return infos;
      }

      infos = SearchByName(name + ".cget", langs);
      if(infos.size())
	return infos;

      return SearchByName(name, langs);
    }
    std::vector<RepoInfo> SearchByName(const std::string& name, const std::vector<std::string>& ls) {
      std::vector<RepoInfo> infos;
  
      std::string q = "in:name " + name + " ";
      for(auto& l : ls) {
	q += "language:" + l + " ";    
      }
      std::cout << q << std::endl;
      q = curl_handle::instance.Escape(q);
      std::string url = "https://api.github.com/search/repositories?q=" + q + "&sort=stars&order=desc";
      auto doc = curl_handle::instance.GetJSON(url);

      if(doc->IsObject() == false) {
	delete doc;
	return infos; 
      }
  
      auto& items = (*doc)["items"];
      infos.reserve(items.Size());
      std::cout << items.Size() << " results" << std::endl;
      for(int forceNameMatch = 1;forceNameMatch >= 0;forceNameMatch--) {
	for(SizeType i = 0;i < items.Size();i++){
	  auto& item = items[i];
	  std::string pname = item["name"].GetString();
	  if( (forceNameMatch == 1) ^ (strcasecmp(pname.c_str(), name.c_str()) == 0))
	    continue;
	  add_to_list(infos, item);
	}
      }
      delete doc; 
      return infos;
    }

    bool CheckExists(const std::string& name) {
      std::string url = "https://api.github.com/repos/" + name + "/releases";
      auto doc = curl_handle::instance.GetJSON(url);
      bool rtn = doc->IsObject() && (*doc)["id"].IsNumber();
      delete doc;
      return rtn;
    }

    RepoInfo Get(const std::string& name) {
      std::string url = "https://api.github.com/repos/" + name;
      auto doc = curl_handle::instance.GetJSON(url);
      RepoInfo rtn = Populate(*doc);
      delete doc;
      return rtn;
    }

    std::string LatestVersionByName(const std::string& name) {
      std::string url = "https://api.github.com/repos/" + name + "/releases";
      auto doc = curl_handle::instance.GetJSON(url);

      if (doc->HasParseError()) {
	fprintf(stderr, "\nError(offset %u): %s\n",
		(unsigned)doc->GetErrorOffset(),
		GetParseError_En(doc->GetParseError()));
	return "";
      }
  
      if(doc->IsArray() == false || doc->Size() == 0) {
	delete doc;
	return "master"; 
      }

      auto& latest = doc[0][0];
      return latest["tag_name"].GetString();
    }

  }
}
