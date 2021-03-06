require 'json'
require 'open-uri'
require 'base64'

require 'webhook_handler'
require 'octokit'
require 'dotenv'
Dotenv.load

# Webhook handler which updates the KuvakaZim Jekyll site's DATASOURCE file
class KuvakazimUpdater
  include WebhookHandler

  begin
    GITHUB_ACCESS_TOKEN = ENV.fetch('GITHUB_ACCESS_TOKEN')
  rescue KeyError => e
    abort "Please set the GITHUB_ACCESS_TOKEN environment variable: #{e}"
  end

  def perform
    datasources = github.contents(repo, path: filename)
    if Base64.decode64(datasources[:content]) == contents
      warn "No changes to #{filename} detected"
      return
    end
    github.update_contents(
      repo,
      filename,
      "Update #{filename}",
      datasources[:sha],
      contents,
      branch: 'master'
    )
  rescue Octokit::NotFound => e
    warn "Couldn't find #{filename}: #{e.message}"
    github.create_contents(
      repo,
      filename,
      "Create #{filename}",
      contents,
      branch: 'master'
    )
  end

  private

  def repo
    @repo ||= 'mysociety/kuvakazim'
  end

  def filename
    @filename ||= 'datasources.json'
  end

  def github
    @github ||= Octokit::Client.new(access_token: GITHUB_ACCESS_TOKEN)
  end

  def contents
    @contents ||= JSON.pretty_generate(
      assembly: {
        popolo: datasource_url(assembly)
      },
      senate: {
        popolo: datasource_url(senate)
      }
    )
  end

  def datasource_url(house)
    "https://cdn.rawgit.com/everypolitician/everypolitician-data/#{house[:sha]}/" \
      "#{house[:popolo]}"
  end

  def assembly
    @assembly ||= zimbabwe[:legislatures].find { |l| l[:slug] == 'Assembly' }
  end

  def senate
    @senate ||= zimbabwe[:legislatures].find { |l| l[:slug] == 'Senate' }
  end

  def zimbabwe
    @zimbabwe ||= countries.find { |c| c[:slug] == 'Zimbabwe' }
  end

  def countries
    @countries ||= JSON.parse(open(countries_url).read, symbolize_names: true)
  end

  def countries_url
    'https://raw.githubusercontent.com/everypolitician/everypolitician-data/' \
      'master/countries.json'
  end
end
