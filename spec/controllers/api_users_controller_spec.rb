# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V0::UsersController do
  describe 'GET show_user_*' do
    let!(:user) { create(:user_with_wca_id, name: "Jeremy") }

    it 'can query by id' do
      get :show_user_by_id, params: { id: user.id }
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["user"]["name"]).to eq "Jeremy"
      expect(json["user"]["wca_id"]).to eq user.wca_id
    end

    it 'can query by wca id' do
      get :show_user_by_wca_id, params: { wca_id: user.wca_id }
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["user"]["name"]).to eq "Jeremy"
      expect(json["user"]["wca_id"]).to eq user.wca_id
    end

    it '404s nicely' do
      get :show_user_by_wca_id, params: { wca_id: "foo" }
      expect(response).to have_http_status :not_found
      json = response.parsed_body
      expect(json["user"]).to be_nil
    end

    describe 'upcoming_competitions' do
      let!(:upcoming_comp) { create(:competition, :confirmed, :visible, starts: 2.weeks.from_now) }
      let!(:registration) { create(:registration, :accepted, user: user, competition: upcoming_comp) }

      it 'does not render upcoming competitions by default' do
        get :show_user_by_id, params: { id: user.id }
        expect(response).to have_http_status :ok
        json = response.parsed_body
        expect(json.keys).not_to include "upcoming_competitions"
      end

      it 'renders upcoming competitions when upcoming_competitions param is set' do
        get :show_user_by_id, params: { id: user.id, upcoming_competitions: true }
        expect(response).to have_http_status :ok
        json = response.parsed_body
        expect(json["upcoming_competitions"].size).to eq 1
      end
    end
  end

  describe 'GET #me' do
    let!(:normal_user) { create(:user_with_wca_id, name: "Jeremy") }

    it 'correctly returns user' do
      sign_in normal_user
      get :show_me
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["user"]).to eq normal_user.serializable_hash(private_attributes: ['email']).as_json
    end
    let!(:id_less_user) { create(:user, email: "example@email.com") }

    it 'correctly returns user without wca_id' do
      sign_in id_less_user
      get :show_me
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["user"]).to eq id_less_user.serializable_hash(private_attributes: ['email']).as_json
    end

    let(:competed_person) { create(:person_who_has_competed_once, name: "Jeremy", wca_id: "2005FLEI01") }
    let!(:competed_user) { create(:user, person: competed_person, email: "example1@email.com") }

    it 'correctly returns user with their prs' do
      sign_in competed_user
      get :show_me
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["user"]).to eq competed_user.serializable_hash(private_attributes: ['email']).as_json
      expect(json.key?("rankings")).to be true
    end
  end

  describe 'GET #permissions' do
    let!(:normal_user) { create(:user_with_wca_id, name: "Jeremy") }
    let!(:senior_delegate_role) { create(:senior_delegate_role) }

    it 'correctly returns user a normal users permission' do
      sign_in normal_user
      get :permissions
      expect(response).to have_http_status :ok
      expect(response.body).to eq normal_user.permissions.to_json
    end
    let!(:banned_user) { create(:user, :banned) }

    it 'correctly returns that a banned user cant compete' do
      sign_in banned_user
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_attend_competitions"]["scope"]).to eq []
    end

    it 'correctly returns a banned users end_date' do
      end_date = (Date.today + 1).to_s
      banned_user.current_ban.update_column("end_date", end_date)
      sign_in banned_user
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_attend_competitions"]["until"]).to eq end_date
    end

    it 'correctly returns wrt to be able to create competitions' do
      sign_in create :user, :wrt_member
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_organize_competitions"]["scope"]).to eq "*"
    end

    it 'correctly returns delegate to be able to create competitions' do
      delegate = create(:delegate_role)
      sign_in delegate.user
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_organize_competitions"]["scope"]).to eq "*"
    end

    it 'correctly returns wst to be able to create competitions' do
      sign_in create :user, :wst_member
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_organize_competitions"]["scope"]).to eq "*"
    end

    it 'correctly returns board to be able to create competitions' do
      sign_in create :user, :board_member
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_organize_competitions"]["scope"]).to eq "*"
    end

    it 'correctly returns board to be able to admin competitions' do
      sign_in create :user, :board_member
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_administer_competitions"]["scope"]).to eq "*"
    end

    it 'correctly returns wrt to be able to admin competitions' do
      sign_in create :user, :wrt_member
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_administer_competitions"]["scope"]).to eq "*"
    end

    it 'correctly returns wst to be able to admin competitions' do
      sign_in create :user, :wst_member
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_administer_competitions"]["scope"]).to eq "*"
    end

    let!(:delegate_user) { create(:delegate_role, group_id: senior_delegate_role.group.id).user }
    let!(:organizer_user) { create(:user) }
    let!(:competition) do
      create(:competition, :confirmed, delegates: [delegate_user], organizers: [organizer_user])
    end

    it 'correctly returns delegates to be able to admin competitions they delegated' do
      sign_in delegate_user
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_administer_competitions"]["scope"]).to eq [competition.id]
    end

    it 'correctly returns organizer to be able to admin competitions they organize' do
      sign_in organizer_user
      get :permissions
      expect(response).to have_http_status :ok
      json = response.parsed_body
      expect(json["can_administer_competitions"]["scope"]).to eq [competition.id]
    end
  end
end
