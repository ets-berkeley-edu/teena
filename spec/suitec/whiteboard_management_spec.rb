require_relative '../../util/spec_helper'

describe 'Whiteboard', order: :defined do

  test_id = Utils.get_test_id
  event = Event.new({test_script: self, test_id: test_id})
  timeout = Utils.short_wait
  whiteboard_asset = nil

  before(:all) do
    @course = Course.new({title: "Whiteboard Management #{test_id}"})
    @course.site_id = ENV['COURSE_ID']

    # Load test data
    admin = User.new({uid: Utils.super_admin_uid, username: Utils.super_admin_username})
    user_test_data = SuiteCUtils.load_suitec_test_data.select { |data| data['tests']['whiteboard_management'] }
    @teacher = User.new user_test_data.find { |data| data['role'] == 'Teacher' }
    students_data = user_test_data.select { |data| data['role'] == 'Student' }
    @student_1 = User.new students_data[0]
    @student_2 = User.new students_data[1]
    @student_3 = User.new students_data[2]

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryDetailPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexConfigPage.new @driver
    @whiteboards = Page::SuiteCPages::WhiteboardPage.new @driver

    # Create course site if necessary
    @canvas.log_in(@cal_net, admin.username, Utils.super_admin_password)
    event.actor = admin
    @canvas.create_generic_course_site(Utils.canvas_qa_sub_account, @course, [@teacher, @student_1, @student_2, @student_3],
                                       test_id, [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX, LtiTools::WHITEBOARDS])

    @asset_library_url = @canvas.click_tool_link(LtiTools::ASSET_LIBRARY, event)
    @engagement_index_url = @canvas.click_tool_link(LtiTools::ENGAGEMENT_INDEX, event)
    @whiteboards_url = @canvas.click_tool_link(LtiTools::WHITEBOARDS, event)
  end

  after(:all) { @driver.quit }

  describe 'creation' do

    before(:all) do
      @whiteboard = Whiteboard.new({owner: @student_1, title: "Whiteboard Creation #{test_id}", collaborators: []})
      @canvas.masquerade_as((event.actor = @student_1), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
    end

    before(:each) do
      @whiteboards.close_whiteboard @driver
      @whiteboards.load_page(@driver, @whiteboards_url, event)
    end

    it 'shows a Create Your First Whiteboard link if the user has no existing whiteboards' do
      create_first_link = @whiteboards.verify_block { @whiteboards.create_first_whiteboard_link_element.when_visible timeout }
      @whiteboards.list_view_whiteboard_elements.any? ?
          (expect(create_first_link).to be false) :
          (expect(create_first_link).to be true)
    end

    it 'requires a title' do
      @whiteboards.click_add_whiteboard
      @whiteboards.click_create_whiteboard
      @whiteboards.title_req_msg_element.when_visible timeout
    end

    it 'permits a title with 255 characters maximum' do
      @whiteboards.click_add_whiteboard
      @whiteboards.enter_whiteboard_title "#{'A loooooong title' * 15}?"
      @whiteboards.click_create_whiteboard
      @whiteboards.title_max_length_msg_element.when_visible timeout
    end

    it 'can be done with the owner as the only member' do
      @whiteboard.title = "#{@whiteboard.title} with owner only"
      @whiteboards.create_and_open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.verify_collaborators [@whiteboard.owner, @whiteboard.collaborators]
    end

    it 'can be done with the owner plus other course site members as whiteboard members' do
      @whiteboard.title = "#{@whiteboard.title} plus members"
      @whiteboard.collaborators = [@student_2, @teacher]
      @whiteboards.create_and_open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.verify_collaborators [@whiteboard.owner, @whiteboard.collaborators]
    end
  end

  describe 'editing' do

    before(:all) do
      editing_test_id = "#{Time.now.to_i}"
      @whiteboard = Whiteboard.new({owner: @student_1, title: "Whiteboard Editing #{editing_test_id}", collaborators: []})
      @whiteboards.close_whiteboard @driver
      @whiteboards.load_page(@driver, @whiteboards_url, event)
    end

    it 'allows the title to be changed' do
      @whiteboard.title = "#{@whiteboard.title} before edit"
      @whiteboards.create_and_open_whiteboard(@driver, @whiteboard, event)
      @whiteboard.title = "#{@whiteboard.title} after edit"
      @whiteboards.edit_whiteboard_title(@whiteboard, event)
      # Verify the page title is updated with the new whiteboard title
      @whiteboards.wait_until(timeout) { @whiteboards.title == @whiteboard.title }
      @whiteboards.close_whiteboard @driver
      # Verify the whiteboard list view shows the new whiteboard title
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.verify_first_whiteboard @whiteboard
    end
  end

  describe 'deleting' do

    before(:all) do
      deleting_test_id = "#{Time.now.to_i}"

      # Student creates two whiteboards
      @canvas.masquerade_as((event.actor = @student_1), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboard_delete_1 = Whiteboard.new({owner: @student_1, title: "Whiteboard Delete 1 #{deleting_test_id}", collaborators: [@student_2]})
      @whiteboards.create_whiteboard(@whiteboard_delete_1, event)
      @whiteboard_delete_2 = Whiteboard.new({owner: @student_1, title: "Whiteboard Delete 2 #{deleting_test_id}", collaborators: []})
      @whiteboards.create_whiteboard(@whiteboard_delete_2, event)
    end

    it 'can be done by a student who is a collaborator on the whiteboard' do
      # Student collaborator deletes board
      @canvas.masquerade_as((event.actor = @student_2), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard_delete_1, event)
      @whiteboards.delete_whiteboard(@driver, event)
      # Deleted board should close and be gone from list view
      @whiteboards.wait_until(Utils.short_wait) { @driver.window_handles.length == 1 }
      expect(@whiteboards.visible_whiteboard_titles).not_to include(@whiteboard_delete_1.title)
    end

    it 'can be done by an instructor who is not a collaborator on the whiteboard' do
      # Teacher deletes other board
      @canvas.masquerade_as((event.actor = @teacher), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard_delete_2, event)
      @whiteboards.delete_whiteboard(@driver, event)
      # Deleted board should close but remain in list view in deleted state
      expect(@driver.window_handles.length).to be 1
      expect(@whiteboards.visible_whiteboard_titles).not_to include(@whiteboard_delete_2.title)
    end

    it 'can be reversed by an instructor' do
      # Teacher restores board
      @whiteboards.advanced_search(@whiteboard_delete_2.title, @student_1, true, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard_delete_2, event)
      @whiteboards.restore_whiteboard
      @whiteboards.close_whiteboard @driver
      @whiteboards.advanced_search(@whiteboard_delete_2.title, @student_1, false, event)
      @whiteboards.wait_until(timeout) { @whiteboards.visible_whiteboard_titles == [@whiteboard_delete_2.title] }
      # Student can now see board again
      @canvas.masquerade_as((event.actor = @student_1), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.wait_until(timeout) { @whiteboards.visible_whiteboard_titles.include? @whiteboard_delete_2.title }
    end

  end

  describe 'search' do

    before(:all) do
      @search_test_id = "#{Time.now.to_i}"
      @whiteboard_1 = Whiteboard.new({owner: @student_1, title: "Whiteboard Search #{@search_test_id} Unique Title", collaborators: []})
      @whiteboard_2 = Whiteboard.new({owner: @student_1, title: "Whiteboard Search #{@search_test_id} Non-unique Title", collaborators: [@teacher]})
      @whiteboard_3 = Whiteboard.new({owner: @student_1, title: "Whiteboard Search #{@search_test_id} Non-unique Title", collaborators: [@teacher, @student_2]})

      @whiteboards.close_whiteboard @driver
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      [@whiteboard_1, @whiteboard_2, @whiteboard_3].each { |whiteboard| @whiteboards.create_whiteboard(whiteboard, event) }
    end

    it ('is not available to a student') { expect(@whiteboards.simple_search_input?).to be false }

    it 'is available to a teacher' do
      @canvas.masquerade_as((event.actor = @teacher), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.simple_search_input_element.when_visible timeout
    end

    it 'allows a teacher to perform a simple search by title that returns results' do
      @whiteboards.simple_search("#{@search_test_id}", event)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.length == 3 }
      @whiteboards.wait_until(timeout) { @whiteboards.visible_whiteboard_titles.sort == [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title].sort }
      expect(@whiteboards.no_results_msg?).to be false
    end

    it 'allows a teacher to perform a simple search by title that returns no results' do
      @whiteboards.simple_search('foo', event)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.empty? }
      @whiteboards.wait_until(timeout) { @whiteboards.no_results_msg? }
    end

    it 'allows a teacher to perform an advanced search by title that returns results' do
      @whiteboards.advanced_search("#{@search_test_id} Non-unique Title", nil, false, event)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.length == 2 }
      @whiteboards.wait_until(timeout) { @whiteboards.visible_whiteboard_titles.sort == [@whiteboard_2.title, @whiteboard_3.title].sort }
      expect(@whiteboards.no_results_msg?).to be false
    end

    it 'allows a teacher to perform an advanced search by title that returns no results' do
      @whiteboards.advanced_search('bar', nil, false, event)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.empty? }
      @whiteboards.wait_until(timeout) { @whiteboards.no_results_msg? }
    end

    it 'allows a teacher to perform an advanced search by collaborator that returns results' do
      @whiteboards.advanced_search(nil, @student_1, false, event)
      # Search could return whiteboards from other test runs, so just verify that those from this run are present too
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.length > 3 }
      @whiteboards.wait_until(timeout) { (@whiteboards.visible_whiteboard_titles & [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title]).length == 2 }
      expect(@whiteboards.no_results_msg?).to be false
    end

    it 'allows a teacher to perform an advanced search by collaborator that returns no results' do
      @whiteboards.advanced_search(nil, @student_3, false, event)
      @whiteboards.wait_until(timeout) { !@whiteboards.visible_whiteboard_titles.include? (@whiteboard_1.title || @whiteboard_2.title || @whiteboard_3.title) }
    end

    it 'allows a teacher to perform an advanced search by title and collaborator that returns results' do
      @whiteboards.advanced_search("#{@search_test_id} Unique Title", @student_1, false, event)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.length == 3 }
      # Expect all 3 whiteboards since all contain the components of the search string
      @whiteboards.wait_until(timeout) { (@whiteboards.visible_whiteboard_titles.sort) == [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title].sort }
      expect(@whiteboards.no_results_msg?).to be false
    end

    it 'allows a teacher to perform an advanced search by title and collaborator that returns no results' do
      @whiteboards.advanced_search("#{@search_test_id} Non-unique Title", @student_3, false, event)
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_whiteboard_elements.empty? }
      @whiteboards.wait_until(timeout) { @whiteboards.no_results_msg? }
    end
  end

  describe 'export' do

    before(:all) do
      export_test_id = "#{Time.now.to_i}"
      @whiteboard = Whiteboard.new({owner: @student_1, title: "Whiteboard Export #{export_test_id}", collaborators: []})

      # Upload assets to be used on whiteboard
      @canvas.masquerade_as((event.actor = @student_1), @course)
      @asset_library.load_page(@driver, @asset_library_url, event)
      user_asset_data = @student_1.assets
      @assets = []
      user_asset_data.each do |data|
        asset = Asset.new data
        asset.title = "#{asset.title} #{test_id}"
        (data['type'] == 'File') ? @asset_library.upload_file_to_library(asset, event) : @asset_library.add_site(asset, event)
        @asset_library.verify_first_asset(@student_1, asset, event)
        @assets << asset
      end

      # Get current score
      @canvas.masquerade_as((event.actor = @teacher), @course)
      @initial_score = @engagement_index.user_score(@driver, @engagement_index_url, @student_1, event)

      # Get configured activity points to determine expected score
      @engagement_index.click_points_config event
      @export_board_points = "#{@engagement_index.activity_points Activity::EXPORT_WHITEBOARD}"
      @score_with_export_whiteboard = @initial_score.to_i + @export_board_points.to_i

      # Create a whiteboard for tests
      @canvas.masquerade_as((event.actor = @student_1), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.create_and_open_whiteboard(@driver, @whiteboard, event)
    end

    after(:each) { @whiteboards.close_whiteboard @driver }

    it 'is not possible if the whiteboard has no assets' do
      @whiteboards.click_export_button
      @whiteboards.export_to_library_button_element.when_visible timeout
      expect(@whiteboards.export_to_library_button_element.attribute('disabled')).to eql('true')
      expect(@whiteboards.download_as_image_button_element.attribute('disabled')).to eql('true')
    end

    it 'as a new asset is possible if the whiteboard has assets' do
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.add_existing_assets(@assets, event)
      @whiteboards.open_original_asset_link_element.when_visible Utils.long_wait
      whiteboard_asset = @whiteboards.export_to_asset_library(@whiteboard, event)
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.verify_first_asset(@student_1, whiteboard_asset, event)
    end

    it 'as a new asset allows a user to remix the whiteboard' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, whiteboard_asset, event)
      remix = @asset_library.click_remix
      expect(remix.title).to eql(@whiteboard.title)
      @asset_library.open_remixed_board(@driver, remix, event)
      @whiteboards.verify_collaborators [@student_1]
    end

    it 'as a new asset earns "Export a whiteboard to the Asset Library" points' do
      @canvas.masquerade_as((event.actor = @teacher), @course)
      expect(@engagement_index.user_score(@driver, @engagement_index_url, @student_1, event)).to eql("#{@score_with_export_whiteboard}")
    end

    it 'as a new asset shows "export_whiteboard" activity on the CSV export' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
      expect(scores).to include("#{@student_1.full_name}, #{Activity::EXPORT_WHITEBOARD.type}, #{@export_board_points}, #{@score_with_export_whiteboard}")
    end

    it 'as a PNG download is possible if the whiteboard has assets' do
      @canvas.masquerade_as((event.actor = @student_1), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.download_as_image
      expect(@whiteboards.verify_image_download(@whiteboard, event)).to be true
    end

    it 'as a PNG download earns no "Export a whiteboard to the Asset Library" points' do
      @canvas.masquerade_as((event.actor = @teacher), @course)
      expect(@engagement_index.user_score(@driver, @engagement_index_url, @student_1, event)).to eql("#{@score_with_export_whiteboard}")
    end
  end

  describe 'asset detail' do

    before(:all) do
      asset_detail_test_id = "#{Time.now.to_i}"
      @canvas.masquerade_as((event.actor = @teacher), @course)
      @asset = Asset.new(@teacher.assets.find { |asset| asset['type'] == 'File' })
      @asset.title = "#{@asset.title} #{test_id}"
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.upload_file_to_library(@asset, event)

      # Create three whiteboards and add the same asset to each
      boards = []
      boards << (@whiteboard_exported = Whiteboard.new({owner: @teacher, title: "Whiteboard Asset Detail #{asset_detail_test_id} Exported", collaborators: []}))
      boards << (@whiteboard_deleted = Whiteboard.new({owner: @teacher, title: "Whiteboard Asset Detail #{asset_detail_test_id} Exported Deleted", collaborators: []}))
      boards << (@whiteboard_non_exported = Whiteboard.new({owner: @teacher, title: "Whiteboard Asset Detail #{asset_detail_test_id} Not Exported", collaborators: []}))
      boards.each do |board|
        @whiteboards.load_page(@driver, @whiteboards_url, event)
        @whiteboards.create_and_open_whiteboard(@driver, board, event)
        @whiteboards.add_existing_assets([@asset], event)
        @whiteboards.close_whiteboard @driver
      end

      # Export two of the boards
      [boards[0], boards[1]].each do |export|
        @whiteboards.load_page(@driver, @whiteboards_url, event)
        @whiteboards.open_whiteboard(@driver, export, event)
        @whiteboards.export_to_asset_library(export, event)
        @whiteboards.close_whiteboard @driver
      end

      # Delete the resulting asset for one of the boards
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.wait_until(Utils.medium_wait) { @asset_library.list_view_asset_link_elements.any? }
      @asset_library.wait_for_load_and_click_js @asset_library.list_view_asset_link_elements.first
      @asset_library.add_event(event, EventType::VIEW_ASSET)
      @asset_library.delete_asset(nil, event)

      # Load the asset's detail
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
    end

    it('lists whiteboard assets that use the asset') { expect(@asset_library.detail_view_whiteboards_list).to include(@whiteboard_exported.title) }

    it('does not list whiteboards that use the asset but have not been exported to the asset library') { expect(@asset_library.detail_view_whiteboards_list).not_to include(@whiteboard_non_exported.title) }

    it('does not list whiteboard assets that use the asset but have since been deleted') { expect(@asset_library.detail_view_whiteboards_list).not_to include(@whiteboard_deleted.title) }

    it('links to the whiteboard asset detail') { @asset_library.click_whiteboard_usage_link(@whiteboard_exported, event) }
  end

  describe 'events' do

    it('record the right number of events') { expect(SuiteCUtils.events_match?(@course, event)).to be true unless ENV['COURSE_ID'] }
  end

end
