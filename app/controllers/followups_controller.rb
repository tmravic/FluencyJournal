class FollowupsController < ApplicationController
  before_action :set_followup

  def new
    @followup = Followup.new
  end

  private

  def followup_params
    params.expect(followup: [ :ai_query_id ])
  end
end
