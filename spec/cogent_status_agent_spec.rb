require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::CogentStatusAgent do
  before(:each) do
    @valid_options = Agents::CogentStatusAgent.new.default_options
    @checker = Agents::CogentStatusAgent.new(:name => "CogentStatusAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
