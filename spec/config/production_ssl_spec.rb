require "rails_helper"
require "open3"

# Boots the production environment in a child process (the test environment
# cannot switch force_ssl on) and checks how requests are treated there.
RSpec.describe "Production SSL configuration" do
  before(:all) do
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1" }
    script = Rails.root.join("spec/support/production_ssl_probe.rb").to_s
    output, status = Open3.capture2e(env, RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", script,
                                     chdir: Rails.root.to_s)
    line = output.lines.find { |l| l.start_with?("PROBE:") }
    raise "production probe failed (exit #{status.exitstatus}):\n#{output.lines.last(15).join}" unless line

    @probe = JSON.parse(line.delete_prefix("PROBE:"))
  end

  let(:probe) { @probe }

  it "forces SSL" do
    expect(probe["force_ssl"]).to be(true)
  end

  it "redirects plain HTTP page requests to HTTPS" do
    expect(probe["http_page"]).to include("status" => 301, "location" => "https://fluencyjournal.com/session/new")
  end

  it "answers the kamal-proxy health check on plain HTTP without a redirect" do
    expect(probe["http_up"]).to include("status" => 200, "location" => nil)
  end

  it "sends Strict-Transport-Security on HTTPS responses" do
    expect(probe["https_up"]["hsts"]).to be_present
    expect(probe["https_page"]["hsts"]).to be_present
  end
end
