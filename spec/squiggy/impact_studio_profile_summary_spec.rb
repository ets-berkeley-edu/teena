require_relative '../../util/spec_helper'

describe 'Impact Studio' do

  test = SquiggyTestConfig.new 'profile_summary'
  test.course.sections = [Section.new(label: test.course.title)]

  teacher = test.teachers[0]
  student_1 = test.students[0]
  student_2 = test.students[1]
  student_3 = test.students[2]

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
    @engagement_index.wait_for_new_user_sync(test, test.course.roster)
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'profile summary' do

    before(:all) do
      @canvas.masquerade_as(student_1, test.course)
      @impact_studio.load_own_profile(test, student_1)
    end

    it('shows the user avatar') { expect(@impact_studio.avatar?).to be true }

    it 'shows no sections section when there is no section' do
      @impact_studio.select_user teacher
      expect(@impact_studio.sections).to be_empty
    end

    it 'shows the sections when there are sections' do
      @impact_studio.select_user student_3
      expect(@impact_studio.sections).to eql(test.course.sections.first.label)
    end

    describe 'last activity' do

      context 'when the user has no activity' do
        it 'shows "Never"' do
          expect(@impact_studio.last_activity).to eql('Never')
        end
      end

      context 'when the user has activity' do

        before(:all) do
          @asset_library.load_page test
          @asset_library.add_link_asset SquiggyAsset.new title: "Asset #{test.id}",
                                                         url: 'www.google.com'
        end

        it 'shows the activity date' do
          @impact_studio.load_own_profile(test, student_1)
          expect(@impact_studio.last_activity).to eql('Today')
        end
      end
    end

    describe 'description' do

      it 'allows the user to edit a description' do
        desc = "My personal description #{test.id}"
        @impact_studio.edit_profile desc
        @impact_studio.wait_until(Utils.short_wait) { @impact_studio.profile_desc == desc }
      end

      it 'allows the user to cancel a description edit' do
        desc = @impact_studio.profile_desc
        @impact_studio.click_edit_profile
        @impact_studio.enter_profile_desc 'foo'
        @impact_studio.cancel_profile_edit
        @impact_studio.wait_until(Utils.short_wait) { @impact_studio.profile_desc == desc }
      end

      it 'allows the user to include a link in a description' do
        link = 'www.google.com'
        @impact_studio.edit_profile "My personal description includes a link to #{link}"
        @impact_studio.wait_until(Utils.short_wait) { @impact_studio.profile_desc.include? 'My personal description includes a link to' }
        expect(@impact_studio.external_link_valid?(@impact_studio.link_element(xpath: "//a[contains(.,'#{link}')]"), 'Google'))
      end

      it 'allows the user to include a hashtag in a description' do
        @impact_studio.switch_to_canvas_iframe
        @impact_studio.edit_profile 'My personal description hashtag #BitterTogether'
        @impact_studio.wait_until(Utils.short_wait) { @impact_studio.profile_desc.include? 'My personal description hashtag' }
        @impact_studio.link_element(text: '#BitterTogether').click
        @asset_library.wait_until(Utils.short_wait) { @asset_library.title == 'Asset Library' }
        @asset_library.switch_to_canvas_iframe
        @asset_library.no_search_results_element.when_visible Utils.short_wait
      end

      it 'allows the user to add a maximum of X characters to a description' do
        desc = "#{'A loooooong title' * 15}?"
        @impact_studio.load_page test
        @impact_studio.click_edit_profile
        @impact_studio.enter_profile_desc desc
        @impact_studio.char_limit_msg_element.when_visible 1
      end

      it 'allows the user to remove a description' do
        @impact_studio.cancel_profile_edit
        @impact_studio.edit_profile ''
        @impact_studio.wait_until(Utils.short_wait, "Expected nothing, got #{@impact_studio.profile_desc}") do
          @impact_studio.profile_desc.empty?
        end
      end
    end
  end

  describe '"looking for collaborators"' do

    context 'when the user is not looking' do

      before(:all) do
        @canvas.masquerade_as(student_1, test.course)
        @impact_studio.load_own_profile(test, student_1)
      end

      context 'and the user views itself' do

        it('shows the right status on the Impact Studio') { @impact_studio.set_collaboration_false }
      end

      context 'and another user views the user' do

        before(:all) do
          @canvas.masquerade_as(student_2, test.course)
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
        @canvas.masquerade_as(student_1, test.course)
        @impact_studio.load_own_profile(test, student_1)
      end

      context 'and the user views itself' do

        it('shows the right status on the Impact Studio') { @impact_studio.set_collaboration_true }

        # TODO it 'shows the right status on the Engagement Index'
      end

      context 'and another user views the user' do

        before(:all) do
          @canvas.masquerade_as(student_2, test.course)
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
          @canvas.message_input_element.when_visible Utils.short_wait
          expect(@canvas.message_addressee_element.attribute('value')).to eql("#{student_1.canvas_id}")
        end
      end
    end
  end
end