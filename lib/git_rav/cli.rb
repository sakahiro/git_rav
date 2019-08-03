require "octokit"
require "open3"
require "digest"
require "erb"
require "yaml"
require "thor"

DEFAULT_MASTER_BRANCH_NAME = "master"
DEFAULT_DEVELOP_BRANCH_NAME = "develop"
DEFAULT_VERSION_FILE_PATH = "version"
TEMPLATE_FILE_NAME = ".git_rav_template"
SETTINGS_FILE_NAME = ".git_rav.yml"
TOKEN_KEY = "git-rav.token"

module GitRav
  class CLI < Thor
    attr_accessor :version_name
    attr_accessor :release_branch_name
    attr_accessor :master_branch_name
    attr_accessor :develop_branch_name
    attr_accessor :remote_repository_name
    attr_accessor :version_file_path
    attr_accessor :client

    desc "prepare VERSION", "create pull requests"
    def prepare(version)
      # TODO: override exists pr
      set_variables(version)

      # TODO: it raise error when same name branch is exist
      develop_branch_sha = client.ref(remote_repository_name, "heads/#{develop_branch_name}").object.sha
      release_branch = client.create_reference(remote_repository_name, "heads/#{release_branch_name}", develop_branch_sha)
      release_branch_ref = release_branch.ref

      # TODO: change ios version file
      content = client.contents(remote_repository_name, path: version_file_path, ref: release_branch_ref)

      client.update_contents(
        remote_repository_name,
        version_file_path,
        version_name,
        content.sha,
        version,
        branch: release_branch_ref
      )

      body = build_pr_body
      client.create_pull_request(remote_repository_name, master_branch_name, release_branch_ref, version_name, body)
      client.create_pull_request(remote_repository_name, develop_branch_name, release_branch_ref, version_name, body)
    end

    desc "release VERSION", "merge pull requests"
    def release(version)
      set_variables(version)

      release_branch = client.ref(remote_repository_name, "heads/#{release_branch_name}")

      target_commitish = release_branch.object.sha
      client.create_release(remote_repository_name, version_name, target_commitish: target_commitish, name: version, body: version_name)

      pull_requests = client.pull_requests(remote_repository_name, state: 'open', head: "#{client.login}:#{release_branch_name}")
      pull_requests.each do |pull_request|
        client.merge_pull_request(remote_repository_name, pull_request.number, commit_message = version_name)
      end

      client.delete_ref(remote_repository_name, "heads/#{release_branch_name}")
    end

    private

    def set_variables(version)
      @version_name = "version#{version}"
      @release_branch_name = "version-#{version}"

      # TODO: it raise error when setting file is not exist
      settings = YAML.load_file(SETTINGS_FILE_NAME)
      @master_branch_name = settings["master_branch_name"] || DEFAULT_MASTER_BRANCH_NAME
      @develop_branch_name = settings["develop_branch_name"] || DEFAULT_DEVELOP_BRANCH_NAME
      @version_file_path = settings["version_file_path"] || DEFAULT_VERSION_FILE_PATH

      access_token = Open3.capture3("git config #{TOKEN_KEY}").first.chomp
      @client = Octokit::Client.new(access_token: access_token)
      @remote_repository_name = Open3.capture3(
        "git config --get remote.origin.url"
      ).first.chomp.match(/^git@github.com:(.+)\.git$/)[1]
    end

    def build_pr_body
      pull_request_titles = Open3.capture3(
        "git log origin/#{master_branch_name}..origin/#{develop_branch_name} --merges --first-parent --pretty=format:'%b'"
      ).first.chomp.split("\n")

      template_path = "#{Dir.pwd}/#{TEMPLATE_FILE_NAME}"

      file = File.read(template_path)
      ERB.new(file).result(binding)
    end
  end
end
