require 'octokit'
require 'eldritch'
require_relative './commit_cache'
require_relative './commit_reader'

Octokit.auto_paginate = true

module PairingMatrix
  class GithubCommitReader < CommitReader
    def initialize(config)
      super(config)
      @github_client = github_client
      @cache = CommitCache.new
    end

    def read(since)
      cache = @cache.get(since)
      return cache unless cache.nil?

      commits = []
      together do
        @config.github_repos.map do |repo|
          async do
            commits << fetch_commits(repo, since)
          end
        end
      end
      result = commits.flatten
      @cache.put(since, result)
      result
    end

    private
    def fetch_commits(repo, since)
      @github_client.commits_since(repo, since).map { |commit| commit.commit.message }
    end

    def github_client
      Octokit.configure {|c| c.api_endpoint = @config.github_url} if @config.github_enterprise?
      if @config.has_github_access_token?
        Octokit::Client.new(:access_token => @config.github_access_token)
      else
        Octokit::Client.new
      end
    end
  end
end