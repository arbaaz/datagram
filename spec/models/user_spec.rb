require 'rails_helper'

describe User do
  let(:user) { FactoryGirl.build(:user).tap{|u| u.save } }

  specify { expect(user).to be_valid }
  specify { expect(user.token).to_not be_nil }



end
