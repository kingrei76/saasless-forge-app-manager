require "net/http"
require "json"
require "uri"

class GithubApiService
  BASE_URL = "https://api.github.com"

  def initialize(access_token:)
    @access_token = access_token
    @uri = URI.parse(BASE_URL)
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = true
  end

  def test_connection
    response = get("/user")
    return { success: true, user: JSON.parse(response.body) } if response.is_a?(Net::HTTPSuccess)

    { success: false, error: "HTTP #{response.code}: #{response.body}" }
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def repos(page: 1, per_page: 100)
    query = URI.encode_www_form(page: page, per_page: per_page, sort: "updated", direction: "desc", type: "all")
    response = get("/user/repos?#{query}")

    return [] unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("GitHub API repos fetch failed: #{e.message}")
    []
  end

  def all_repos
    all = []
    page = 1

    loop do
      batch = repos(page: page, per_page: 100)
      break if batch.empty?

      all.concat(batch)
      break if batch.size < 100

      page += 1
    end

    all
  end

  def latest_commit(owner:, repo:, branch: "main")
    query = URI.encode_www_form(sha: branch, per_page: 1)
    response = get("/repos/#{owner}/#{repo}/commits?#{query}")

    return nil unless response.is_a?(Net::HTTPSuccess)

    commits = JSON.parse(response.body)
    commits.first
  rescue StandardError => e
    Rails.logger.error("GitHub API commit fetch failed: #{e.message}")
    nil
  end

  def commits(repo:, branch: nil, per_page: 10)
    branch ||= "main"
    query = URI.encode_www_form(sha: branch, per_page: per_page)
    response = get("/repos/#{repo}/commits?#{query}")

    return [] unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("GitHub commits fetch failed: #{e.message}")
    []
  end

  # Get repository tree (file structure)
  def repo_tree(repo:, branch: "main", recursive: true)
    response = get("/repos/#{repo}/git/trees/#{branch}?recursive=#{recursive ? 1 : 0}")

    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    data["tree"] || []
  rescue StandardError => e
    Rails.logger.error("GitHub tree fetch failed: #{e.message}")
    nil
  end

  # Get repository languages (programming languages used)
  def repo_languages(repo:)
    response = get("/repos/#{repo}/languages")

    return {} unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("GitHub languages fetch failed: #{e.message}")
    {}
  end

  # Get file contents
  def file_contents(repo:, path:, branch: "main")
    response = get("/repos/#{repo}/contents/#{path}?ref=#{branch}")

    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    return nil unless data["content"]

    # Decode base64 content
    Base64.decode64(data["content"])
  rescue StandardError => e
    Rails.logger.error("GitHub file contents fetch failed: #{e.message}")
    nil
  end

  # Get a summary of the repo structure for AI scoping
  def repo_structure_summary(repo:, branch: "main")
    tree = repo_tree(repo: repo, branch: branch)
    return nil unless tree

    languages = repo_languages(repo: repo)

    # Group files by type/directory
    structure = {
      languages: languages,
      total_files: tree.count { |item| item["type"] == "blob" },
      directories: [],
      key_files: []
    }

    # Find key configuration/entry files
    key_file_patterns = %w[
      README.md readme.md
      package.json Gemfile requirements.txt pyproject.toml
      docker-compose.yml Dockerfile
      config/routes.rb app/controllers app/models
      src/index.js src/App.tsx pages/_app.tsx
      .env.example
    ]

    tree.each do |item|
      # Collect top-level directories
      if item["type"] == "tree" && !item["path"].include?("/")
        structure[:directories] << item["path"]
      end

      # Identify key files
      key_file_patterns.each do |pattern|
        if item["path"] == pattern || item["path"].start_with?(pattern)
          structure[:key_files] << item["path"] unless structure[:key_files].include?(item["path"])
        end
      end
    end

    # Limit key files to first 20
    structure[:key_files] = structure[:key_files].first(20)

    structure
  rescue StandardError => e
    Rails.logger.error("GitHub structure summary failed: #{e.message}")
    nil
  end

  private

  def get(path)
    request = Net::HTTP::Get.new(path)
    request["Authorization"] = "Bearer #{@access_token}"
    request["Accept"] = "application/vnd.github+json"
    request["X-GitHub-Api-Version"] = "2022-11-28"
    @http.request(request)
  end
end
