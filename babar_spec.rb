require './babar.rb'
require 'time'

describe Babar::Base do
  it 'should create a base authenticator object from uid, password, token, and time' do
    authenticator = Babar::Base.new( { :toodle_uid => "", :toodle_password => "", :session_token => "", :toodle_token_death => Time.now + 14400 })
    authenticator.should be_true
  end

  it 'should raise an exception if empty hash is  passed' do
    expect {authenticator = Babar::Base.new({})}.to raise_error(ArgumentError)
  end

  it 'should create a base authenticator object from just a uid and password' do
    authenticator = Babar::Base.new( {:toodle_uid => "", :toodle_password => ""})
    authenticator.should be_true
  end
 

end
