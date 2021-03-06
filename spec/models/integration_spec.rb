require 'rails_helper'

describe "Models" do


  it "should do everything properly" do
    pending
    self.use_transactional_fixtures = false
    Datagram.destroy_all
    Watch.destroy_all
    WatchResponse.destroy_all
    @user = FactoryGirl.create(:user)
    @watch = FactoryGirl.build(:watch,
                              url: "https://api.forecast.io/forecast/d85744ba9a05b8b90909787e7f513821/19,73",
                              user_id: @user.id,
                              keep_keys: {"data"=>{"currently"=>{"summary" => true}, "hourly"=>{"summary"=>true, "icon"=>true}}},
                              strip_keys: {"data"=>{"latitude"=>true, "longitude"=>true, "currently"=>{"time"=>true}}}
                               ).tap{|w| w.save}

    # Run it once

    # Publish a watch in preview mode.
    @watch.publish(preview: true)
    expect(WatchResponse.count).to eq 1
    @watch_response = WatchResponse.last

    # mark the response
    response = File.read('spec/fixtures/r.json')
    json = JSON.parse(response)
    json["id"] = WatchResponse.last.token
    handler = WatchResponseHandler.new(json)
    handler.handle!

    #assert correct
    @watch_response.reload
    expect(@watch_response).to be_modified
    expect(@watch.last_good_response).to eq @watch_response

    # Run it again
    @watch = Watch.last
    @watch.publish(preview: true)
    expect(WatchResponse.count).to eq 2
    @watch_response_2 = WatchResponse.last
    response = File.read('spec/fixtures/r.json')
    json = JSON.parse(response)
    json["id"] = WatchResponse.last.token
    handler = WatchResponseHandler.new(json)
    handler.handle!
    @watch_response.reload
    @watch.reload

    # check for modification
    expect(@watch_response_2).to_not be_modified
    expect(@watch.last_good_response).to eq @watch_response_2

    # Now try a datagram
    @datagram = Datagram.new(watch_ids: [@watch.id], name: "foo")
    @datagram.save
    expect(@datagram.id).to_not be_nil
    @datagram.publish
    expect(@datagram.last_update_timestamp).to be_nil
    @wr = WatchResponse.last
    response = File.read('spec/fixtures/d.json')
    json = JSON.parse(response)
    json["datagram_id"] = @datagram.reload.token
    json["responses"][0]["id"] = @wr.token
    DatagramResponseHandler.new(json).handle!
    @datagram.reload
    expect(@wr.reload.params).to be_nil
    expect(@datagram.last_update_timestamp).to_not be_nil

    # Now a datagram for a  parameterized watch
    default_params = {date: "2014-09-03" }
    @watch = FactoryGirl.create(:watch, params: default_params)
    @datagram = FactoryGirl.create(:datagram, watch_ids: [@watch.id])
    @datagram.publish
    @wr = WatchResponse.last
    expect(@wr.reload.params).to eq(default_params.stringify_keys)


    # Now persist the report_time
    # First, when nothing specified, make it the current time

    @watch = FactoryGirl.create(:watch)
    response = File.read('spec/fixtures/r.json')
    json = JSON.parse(response)
    json["id"] = WatchResponse.last.token
    handler = WatchResponseHandler.new(json)
    handler.handle!
    @watch.publish
    @wr = WatchResponse.last
    expect(@wr.report_time).to be_a(DateTime)

    # When a time is specified, it should be saved as the report time


  end



end
