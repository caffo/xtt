require File.dirname(__FILE__) + '/../spec_helper'
require 'im/response'


describe IM::Response do
  before do
    @user = mock_model(User)
    User.should_receive(:find_by_aim_login).with("joe").and_return(@user)
    @aim = mock("aim", :screen_name => "joe")
  end
  
  it "knows 'help'" do
    @aim.should_receive(:send_im).with("<HTML>I'm a time-tracker bot. Send me a status message like <b>@project hacking on \#54</b></HTML> or 'commands' for a list of commands")
    im = IM::Response.new "help", @aim
  end
  
  it "knows 'projects'" do
    @user.should_receive(:projects).and_return [mock_model(Project, :code => "tt")]
    @aim.should_receive(:send_im).with("Your projects are: tt")
    im = IM::Response.new "projects", @aim
  end
  
  it "creates a status" do
    @project = mock_model(Project, :name => "Fools!")
    @status  = mock_model(Status, :project => @project, :message => "thanks!")
    @user.should_receive(:post).with("@foo bar", nil).and_return(@status)
    @aim.should_receive :send_im
    im = IM::Response.new "@foo bar", @aim
  end
end
