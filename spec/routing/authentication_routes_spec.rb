require "rails_helper"

RSpec.describe "Authentication routes", type: :routing do
  it "routes the session actions that exist" do
    expect(get: "/session/new").to route_to("sessions#new")
    expect(post: "/session").to route_to("sessions#create")
    expect(delete: "/session").to route_to("sessions#destroy")
  end

  it "has no route for session actions that are not implemented" do
    expect(get: "/session").not_to be_routable
    expect(get: "/session/edit").not_to be_routable
    expect(patch: "/session").not_to be_routable
  end

  it "routes the password reset actions that exist" do
    expect(get: "/passwords/new").to route_to("passwords#new")
    expect(post: "/passwords").to route_to("passwords#create")
    expect(get: "/passwords/abc/edit").to route_to("passwords#edit", token: "abc")
    expect(put: "/passwords/abc").to route_to("passwords#update", token: "abc")
  end

  it "has no route for password actions that are not implemented" do
    expect(get: "/passwords").not_to be_routable
    expect(get: "/passwords/abc").not_to be_routable
    expect(delete: "/passwords/abc").not_to be_routable
  end
end
