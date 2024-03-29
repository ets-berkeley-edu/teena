require_relative '../../util/spec_helper'

describe 'Impact Studio' do

  test = SquiggyTestConfig.new 'studio_profile'
  teacher = test.teachers[0]
  student_1 = test.students[0]
  student_2 = test.students[1]
  student_3 = test.students[2]
  students = [student_1, student_2, student_3]
  test.course_site.manual_members -= students

  before(:all) do
    @driver = Utils.launch_browser chrome_3rd_party_cookies: true
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course_site test
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when there are fewer than two members of the course site' do

    context 'and the course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(teacher, test.course_site)
        @impact_studio.load_own_profile(test, teacher)
      end

      it 'offers a user search field' do
        @impact_studio.user_select_element.when_present Utils.short_wait
        expect(@impact_studio.user_select_options.map &:strip).to eql([teacher.full_name])
      end
      it 'offers user profile pagination' do
        expect(@impact_studio.browse_previous_element.text).to include(teacher.full_name)
        expect(@impact_studio.browse_next_element.text).to include(teacher.full_name)
      end
    end
  end

  context 'when there are exactly two members of the course site' do

    before(:all) do
      @canvas.stop_masquerading
      @canvas.add_users_by_section(test.course_site, [student_1])
    end

    context 'and a course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(student_1, test.course_site)
        @impact_studio.load_own_profile(test, student_1)
      end

      it 'offers a user search field' do
        @impact_studio.user_select_element.when_present Utils.short_wait
        expect(@impact_studio.user_select_options.map &:strip).to eql([teacher.full_name, student_1.full_name])
      end
      it 'offers user profile pagination' do
        expect(@impact_studio.browse_previous_element.text).to include(teacher.full_name)
        expect(@impact_studio.browse_next_element.text).to include(teacher.full_name)
      end
    end
  end

  context 'when there are more than two members of the course site' do

    before(:all) do
      @canvas.stop_masquerading
      @canvas.add_users_by_section(test.course_site, [student_2])
    end

    context 'and a course site member views its profile' do

      before(:all) do
        @canvas.masquerade_as(student_2, test.course_site)
        @impact_studio.load_own_profile(test, student_2)
      end

      it 'offers a user search field' do
        @impact_studio.user_select_element.when_present Utils.short_wait
        expect(@impact_studio.user_select_options.map(&:strip).sort).to eql([teacher.full_name, student_1.full_name, student_2.full_name].sort)
      end
      it 'offers user profile pagination' do
        expect([student_1.full_name, teacher.full_name]).to include(@impact_studio.browse_previous_element.text.delete('<>').strip)
        expect([student_1.full_name, teacher.full_name]).to include(@impact_studio.browse_next_element.text.delete('<>').strip)
      end
    end
  end

  describe 'search' do

    before(:all) do
      @canvas.masquerade_as(teacher, test.course_site)
      @impact_studio.load_own_profile(test, teacher)
    end

    [student_1, student_2].each do |student|
      it "allows the user to view UID #{student.uid}'s profile" do
        @impact_studio.select_user student
        @impact_studio.wait_for_profile student
      end
    end
  end

  describe 'pagination' do

    before(:all) do
      @users = [teacher, student_1, student_2]
      @canvas.masquerade_as student_1
      @impact_studio.load_own_profile(test, student_1)
    end

    it 'allows the user to page next through each course site member' do
      @users.sort_by! { |u| u.full_name }
      index_of_current_user = @users.index student_1
      @users.rotate!(index_of_current_user + 1)
      @users.each { |user| @impact_studio.browse_next_user user }
    end

    it 'allows the user to page previous through each course site member' do
      @users.reverse!
      index_of_current_user = @users.index(student_1)
      @users.rotate!(index_of_current_user + 1)
      @users.each { |user| @impact_studio.browse_previous_user user }
    end
  end

  describe 'profile summary' do

    before(:all) do
      @canvas.stop_masquerading
      @canvas.add_users_by_section(test.course_site, [student_3])
      @engagement_index.wait_for_new_user_sync(test, [student_3])

      @asset = SquiggyAsset.new title: "Asset #{test.id}",
                                url: 'www.google.com',
                                description: 'BitterTogether'
      @canvas.masquerade_as(student_1, test.course_site)
      @impact_studio.load_own_profile(test, student_1)
    end

    it('shows the user avatar') { expect(@impact_studio.avatar?).to be true }

    it 'shows the sections when there are sections' do
      @impact_studio.select_user student_3
      expect(@impact_studio.sections).to eql(student_3.sections.first.sis_id)
    end

    describe 'last activity' do

      context 'when the user has no activity' do
        it 'shows "Never"' do
          @impact_studio.last_activity_element.when_visible Utils.short_wait
          expect(@impact_studio.last_activity).to eql('Never')
        end
      end

      context 'when the user has activity' do

        before(:all) do
          @asset_library.load_page test
          @asset_library.add_link_asset @asset
        end

        it 'shows the activity date' do
          @impact_studio.load_own_profile(test, student_1)
          @impact_studio.last_activity_element.when_visible Utils.short_wait
          expect(@impact_studio.last_activity).to eql('a few seconds ago')
        end
      end
    end

    describe 'description' do

      it 'allows the user to edit a description' do
        desc = "My personal description #{test.id}"
        @impact_studio.edit_profile desc
        @impact_studio.wait_until(Utils.short_wait) do
          @impact_studio.profile_desc?
          sleep 2
          @impact_studio.profile_desc == desc
        end
      end

      it 'allows the user to cancel a description edit' do
        desc = @impact_studio.profile_desc
        @impact_studio.click_edit_profile
        @impact_studio.enter_profile_desc 'foo'
        @impact_studio.cancel_profile_edit
        @impact_studio.wait_until(Utils.short_wait) do
          @impact_studio.profile_desc?
          sleep 2
          @impact_studio.profile_desc == desc
        end
      end

      it 'allows the user to include a link in a description' do
        link = 'www.google.com'
        @impact_studio.edit_profile "My personal description includes a link to #{link}"
        @impact_studio.wait_until(Utils.short_wait) do
          @impact_studio.profile_desc?
          sleep 2
          @impact_studio.profile_desc.include? 'My personal description includes a link to'
        end
        expect(@impact_studio.external_link_valid?(@impact_studio.link_element(xpath: "//a[contains(.,'#{link}')]"), 'Google'))
      end

      it 'allows the user to include a hashtag in a description' do
        @impact_studio.load_page test
        @impact_studio.edit_profile 'My personal description hashtag #BitterTogether'
        @impact_studio.wait_until(Utils.short_wait) do
          @impact_studio.profile_desc?
          sleep 2
          @impact_studio.profile_desc.include? 'My personal description hashtag'
        end
        @impact_studio.link_element(text: '#BitterTogether').click
        @asset_library.wait_until(Utils.short_wait) { @asset_library.title == 'Asset Library' }
        @asset_library.switch_to_canvas_iframe
        @asset_library.wait_for_asset_results [@asset]
      end

      it 'allows the user to add a maximum of X characters to a description' do
        desc = "#{'A loooooong title' * 15}?"[0..254]
        @impact_studio.load_page test
        @impact_studio.click_edit_profile
        @impact_studio.enter_profile_desc desc
        @impact_studio.char_limit_msg_element.when_visible 1
      end

      it 'allows the user to remove a description' do
        @impact_studio.cancel_profile_edit
        @impact_studio.edit_profile ''
        @impact_studio.profile_desc_element.when_not_present Utils.short_wait
      end
    end
  end

  describe '"looking for collaborators"' do

    context 'when the user is not looking' do

      before(:all) do
        @canvas.masquerade_as(student_1, test.course_site)
        @engagement_index.load_page test
        @engagement_index.share_score
        @impact_studio.load_own_profile(test, student_1)
      end

      context 'and the user views itself' do

        it('shows the right status on the Impact Studio') { @impact_studio.set_collaboration_false }
      end

      context 'and another user views the user' do

        before(:all) do
          @canvas.masquerade_as(student_2, test.course_site)
          @impact_studio.load_page test
          @impact_studio.select_user student_1
        end

        it('shows no collaboration element on the Impact Studio') { expect(@impact_studio.collaboration_button?).to be false }

        it 'shows the right status on the Engagement Index' do
          @engagement_index.load_page test
          @engagement_index.share_score
          expect(@engagement_index.collaboration_button_element(student_1).exists?).to be false
        end
      end
    end

    context 'when the user is looking' do

      before(:all) do
        @canvas.masquerade_as(student_1, test.course_site)
        @impact_studio.load_own_profile(test, student_1)
      end

      context 'and the user views itself' do

        it('shows the right status on the Impact Studio') { @impact_studio.set_collaboration_true }

        it 'shows no collaborate button on the Engagement Index' do
          @engagement_index.load_page test
          @engagement_index.wait_for_scores
          expect(@engagement_index.collaboration_button_element(student_1).exists?).to be false
        end
      end

      context 'and another user views the user' do

        before(:all) do
          @canvas.masquerade_as(student_2, test.course_site)
          @impact_studio.load_page test
          @impact_studio.select_user student_1
        end

        it('shows a collaborate button on the Impact Studio') { expect(@impact_studio.collaboration_button?).to be true }

        it 'shows a collaborate button on the Engagement Index' do
          @engagement_index.load_page test
          @engagement_index.collaboration_button_element(student_1).when_present Utils.short_wait
        end

        it 'directs the user to the Canvas messaging feature' do
          @engagement_index.click_collaborate_button student_1
          @canvas.msg_recipient_el(student_1).when_present Utils.short_wait
        end
      end
    end
  end
end
