require_relative '../../util/spec_helper'

describe 'Whiteboard' do

  before(:all) do
    @test = SquiggyTestConfig.new 'whiteboard_mgmt'
    @teacher = @test.teachers.first
    @student_1 = @test.students[0]
    @student_2 = @test.students[1]
    @student_3 = @test.students[2]

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver
    @whiteboards = SquiggyWhiteboardPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test
  end

  after(:all) { @driver.quit }
  
  describe 'creation' do

    before(:all) do
      @whiteboard = SquiggyWhiteboard.new(
        owner: @student_1, 
        title: "Whiteboard Creation #{@test.id}",
        collaborators: []
      )
      @canvas.masquerade_as(@student_1, @test.course)
      @whiteboards.load_page @test
    end

    before(:each) do
      @whiteboards.close_whiteboard
      @whiteboards.load_page @test
    end

    it 'requires a title' do
      @whiteboards.click_add_whiteboard
      @whiteboards.save_whiteboard_button_element.when_present Utils.short_wait
      expect(@whiteboards.save_button_element.enabled?).to be false
    end

    it 'permits a title with 255 characters maximum' do
      @whiteboards.click_add_whiteboard
      @whiteboards.enter_whiteboard_title "#{'A loooooong title' * 15}?"
      @whiteboards.title_length_at_max_msg_element.when_visible 2
    end

    it 'can be done with the owner as the only member' do
      @whiteboard.title = "#{@whiteboard.title} with owner only"
      @whiteboards.create_and_open_whiteboard @whiteboard
      @whiteboards.verify_collaborators [@whiteboard.owner, @whiteboard.collaborators]
    end

    it 'can be done with the owner plus other course site members as whiteboard members' do
      @whiteboard.title = "#{@whiteboard.title} plus members"
      @whiteboard.collaborators = [@student_2, @teacher]
      @whiteboards.create_and_open_whiteboard @whiteboard
      @whiteboards.verify_collaborators [@whiteboard.owner, @whiteboard.collaborators]
    end
  end

  describe 'editing' do

    before(:all) do
      @whiteboard = SquiggyWhiteboard.new(
        owner: @student_1,
        title: "Whiteboard Editing #{Time.now.to_i}",
        collaborators: []
      )
      @whiteboards.close_whiteboard
      @whiteboards.load_page @test
    end

    it 'allows the title to be changed' do
      @whiteboard.title = "#{@whiteboard.title} before edit"
      @whiteboards.create_and_open_whiteboard @whiteboard
      @whiteboard.title = "#{@whiteboard.title} after edit"
      @whiteboards.edit_whiteboard_title @whiteboard
    end

    it 'shows the edited whiteboard title' do
      @whiteboards.wait_until(Utils.short_wait) { @whiteboards.title == @whiteboard.title }
    end

    it 'shows the edited whiteboard title in list view' do
      @whiteboards.close_whiteboard
      @whiteboards.load_page @test
      @whiteboards.verify_first_whiteboard @whiteboard
    end
  end

  describe 'deleting' do

    before(:all) do
      deleting_test_id = "#{Time.now.to_i}"
      @whiteboard_delete_1 = SquiggyWhiteboard.new(
        owner: @student_1,
        title: "Whiteboard Delete 1 #{deleting_test_id}",
        collaborators: [@student_2]
      )
      @whiteboard_delete_2 = SquiggyWhiteboard.new(
        owner: @student_1,
        title: "Whiteboard Delete 2 #{deleting_test_id}",
        collaborators: []
      )

      @canvas.masquerade_as(@student_1, @test.course)
      @whiteboards.load_page @test
      @whiteboards.create_whiteboard @whiteboard_delete_1
      @whiteboards.create_whiteboard @whiteboard_delete_2
    end

    it 'can be done by a student who is a collaborator on the whiteboard' do
      @canvas.masquerade_as(@student_2, @test.course)
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard_delete_1
      @whiteboards.delete_whiteboard
      expect(@whiteboards.window_count).to eql(1)
      expect(@whiteboards.visible_whiteboard_titles).not_to include(@whiteboard_delete_1.title)
    end

    it 'can be done by an instructor who is not a collaborator on the whiteboard' do
      @canvas.masquerade_as(@teacher, @test.course)
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard_delete_2
      @whiteboards.delete_whiteboard
      expect(@whiteboards.window_count).to eql(1)
      expect(@whiteboards.visible_whiteboard_titles).not_to include(@whiteboard_delete_2.title)
    end

    it 'can be reversed by an instructor' do
      @whiteboards.advanced_search(@whiteboard_delete_2.title, @student_1, true)
      @whiteboards.open_whiteboard @whiteboard_delete_2
      @whiteboards.restore_whiteboard
      @whiteboards.close_whiteboard
      @whiteboards.advanced_search(@whiteboard_delete_2.title, @student_1, false)
      @whiteboards.wait_until(Utils.short_wait) { @whiteboards.visible_whiteboard_titles == [@whiteboard_delete_2.title] }

      # Student can now see board again
      @canvas.masquerade_as(@student_1, @test.course)
      @whiteboards.load_page @test
      @whiteboards.wait_until(Utils.short_wait) { @whiteboards.visible_whiteboard_titles.include? @whiteboard_delete_2.title }
    end
  end

  describe 'search' do

    before(:all) do
      @search_test_id = Time.now.to_i.to_s
      @whiteboard_1 = SquiggyWhiteboard.new(
        owner: @student_1,
        title: "Whiteboard Search #{@search_test_id} Unique Title",
        collaborators: []
      )
      @whiteboard_2 = SquiggyWhiteboard.new(
        owner: @student_1,
        title: "Whiteboard Search #{@search_test_id} Non-unique Title",
        collaborators: [@teacher]
      )
      @whiteboard_3 = SquiggyWhiteboard.new(
        owner: @student_1,
        title: "Whiteboard Search #{@search_test_id} Non-unique Title",
        collaborators: [@teacher, @student_2]
      )

      @whiteboards.close_whiteboard
      @whiteboards.load_page @test
      [@whiteboard_1, @whiteboard_2, @whiteboard_3].each { |wb| @whiteboards.create_whiteboard wb }
    end

    it('is not available to a student') { expect(@whiteboards.simple_search_input?).to be false }

    it 'is available to a teacher' do
      @canvas.masquerade_as(@teacher, @test.course)
      @whiteboards.load_page @test
      @whiteboards.simple_search_input_element.when_visible Utils.short_wait
    end

    it 'allows a teacher to perform a simple search by title that returns results' do
      @whiteboards.simple_search @search_test_id
      @whiteboards.wait_until(Utils.short_wait) do
        @whiteboards.list_view_whiteboard_elements.length == 3
        @whiteboards.visible_whiteboard_titles.sort == [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title].sort
        !@whiteboards.no_results_msg?
      end
    end

    it 'allows a teacher to perform a simple search by title that returns no results' do
      @whiteboards.simple_search 'foo'
      @whiteboards.wait_until(Utils.short_wait) do
        @whiteboards.list_view_whiteboard_elements.empty?
        @whiteboards.no_results_msg?
      end
    end

    it 'allows a teacher to perform an advanced search by title that returns results' do
      @whiteboards.advanced_search("#{@search_test_id} Non-unique Title", nil, false)
      @whiteboards.wait_until(Utils.short_wait) do
        @whiteboards.list_view_whiteboard_elements.length == 2
        @whiteboards.visible_whiteboard_titles.sort == [@whiteboard_2.title, @whiteboard_3.title].sort
        !@whiteboards.no_results_msg?
      end
    end

    it 'allows a teacher to perform an advanced search by title that returns no results' do
      @whiteboards.advanced_search('bar', nil, false, event)
      @whiteboards.wait_until(Utils.short_wait) { @whiteboards.list_view_whiteboard_elements.empty? }
      @whiteboards.wait_until(Utils.short_wait) { @whiteboards.no_results_msg? }
    end

    it 'allows a teacher to perform an advanced search by collaborator that returns results' do
      @whiteboards.advanced_search(nil, @student_1, false, event)
      # Search could return whiteboards from other test runs, so just verify that those from this run are present too
      @whiteboards.wait_until(Utils.short_wait) { @whiteboards.list_view_whiteboard_elements.length > 3 }
      @whiteboards.wait_until(Utils.short_wait) { (@whiteboards.visible_whiteboard_titles & [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title]).length == 2 }
      expect(@whiteboards.no_results_msg?).to be false
    end

    it 'allows a teacher to perform an advanced search by collaborator that returns no results' do
      @whiteboards.advanced_search(nil, @student_3, false)
      @whiteboards.wait_until(Utils.short_wait) do
        !@whiteboards.visible_whiteboard_titles.include?(@whiteboard_1.title || @whiteboard_2.title || @whiteboard_3.title)
      end
    end

    it 'allows a teacher to perform an advanced search by title and collaborator that returns results' do
      @whiteboards.advanced_search("#{@search_test_id} Unique Title", @student_1, false)
      @whiteboards.wait_until(Utils.short_wait) do
        @whiteboards.list_view_whiteboard_elements.length == 3
        @whiteboards.visible_whiteboard_titles.sort == [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title].sort
        !@whiteboards.no_results_msg?
      end
    end

    it 'allows a teacher to perform an advanced search by title and collaborator that returns no results' do
      @whiteboards.advanced_search("#{@search_test_id} Non-unique Title", @student_3, false)
      @whiteboards.wait_until(Utils.short_wait) do
        @whiteboards.list_view_whiteboard_elements.empty?
        @whiteboards.no_results_msg?
      end
    end
  end

  describe 'export' do

    before(:all) do
      @whiteboard = SquiggyWhiteboard.new(
        owner: @student_1,
        title: "Whiteboard Export #{Time.now.to_i}",
        collaborators: []
      )

      # Upload assets to be used on whiteboard
      @canvas.masquerade_as(@student_1, @test.course)
      @asset_library.load_page @test
      @student_1.assets.each do |asset|
        asset.file_name ? @asset_library.upload_file_asset(asset) : @asset_library.add_link_asset(asset)
      end

      # Get current score
      @canvas.masquerade_as(@teacher, @test.course)
      @initial_score = @engagement_index.user_score(@test, @student_1)

      # Get configured activity points to determine expected score
      @engagement_index.click_points_config
      @export_board_points = "#{@engagement_index.activity_points SquiggyActivity::EXPORT_WHITEBOARD}"
      @score_after_export = @initial_score + @export_board_points

      # Create a whiteboard for tests
      @canvas.masquerade_as(@student_1, @test.course)
      @whiteboards.load_page @test
      @whiteboards.create_and_open_whiteboard @whiteboard
    end

    after(:each) { @whiteboards.close_whiteboard }

    it 'is not possible if the whiteboard has no assets' do
      @whiteboards.click_export_button
      @whiteboards.export_to_library_button_element.when_visible 2
      expect(@whiteboards.export_to_library_button_element.attribute('disabled')).to eql('true')
      expect(@whiteboards.download_as_image_button_element.attribute('disabled')).to eql('true')
    end

    it 'as a new asset is possible if the whiteboard has assets' do
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.add_existing_assets @assets
      @whiteboards.open_original_asset_link_element.when_visible Utils.long_wait
      @whiteboards.export_to_asset_library @whiteboard
    end

    it 'as a new asset allows a user to remix the whiteboard' do
      @asset_library.load_asset_detail(@test, @whiteboard.asset_exports.first)
      remix = @asset_library.click_remix
      expect(remix.title).to eql(@whiteboard.title)
      @asset_library.open_remixed_board remix
      @whiteboards.verify_collaborators [@student_1]
    end

    it 'as a new asset earns "Export a whiteboard to the Asset Library" points' do
      @canvas.masquerade_as(@teacher, @test.course)
      expect(@engagement_index.user_score(@test, @student_1)).to eql("#{@score_after_export}")
    end

    it 'as a new asset shows "export_whiteboard" activity on the CSV export' do
      scores = @engagement_index.download_csv @test
      expect(scores).to include("#{@student_1.full_name}, #{Activity::EXPORT_WHITEBOARD.type}, #{@export_board_points}, #{@score_after_export}")
    end

    it 'as a PNG download is possible if the whiteboard has assets' do
      @canvas.masquerade_as(@student_1, @test.course)
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.download_as_image
      expect(@whiteboards.verify_image_download(@whiteboard)).to be true
    end

    it 'as a PNG download earns no "Export a whiteboard to the Asset Library" points' do
      @canvas.masquerade_as(@teacher, @test.course)
      expect(@engagement_index.user_score(@test, @student_1)).to eql("#{@score_after_export}")
    end
  end

  describe 'asset detail' do

    before(:all) do
      asset_detail_test_id = Time.now.to_i
      @canvas.masquerade_as(@teacher, @test.course)
      @asset = @teacher.assets.find &:file_name
      @asset_library.load_page @test
      @asset_library.upload_file_asset @asset

      # Create three whiteboards and add the same asset to each
      boards = []
      boards << (@whiteboard_exported = SquiggyWhiteboard.new(
        owner: @teacher,
        title: "Whiteboard Asset Detail #{asset_detail_test_id} Exported",
        collaborators: []
      ))
      boards << (@whiteboard_deleted = SquiggyWhiteboard.new(
        owner: @teacher,
        title: "Whiteboard Asset Detail #{asset_detail_test_id} Exported Deleted",
        collaborators: []
      ))
      boards << (@whiteboard_non_exported = SquiggyWhiteboard.new(
        owner: @teacher,
        title: "Whiteboard Asset Detail #{asset_detail_test_id} Not Exported",
        collaborators: []
      ))
      boards.each do |board|
        @whiteboards.load_page @test
        @whiteboards.create_and_open_whiteboard board
        @whiteboards.add_existing_assets [@asset]
        @whiteboards.close_whiteboard
      end

      # Export two of the boards
      [boards[0], boards[1]].each do |export|
        @whiteboards.open_whiteboard export
        @whiteboards.export_to_asset_library export
        @whiteboards.close_whiteboard
      end

      # Delete the resulting asset for one of the boards
      @asset_library.load_page @test
      @asset_library.wait_until(Utils.medium_wait) { @asset_library.list_view_asset_link_elements.any? }
      @asset_library.wait_for_load_and_click_js @asset_library.list_view_asset_link_elements.first
      @asset_library.delete_asset

      # Load the asset's detail
      @asset_library.load_asset_detail(@test, @asset)
    end

    it 'lists whiteboard assets that use the asset' do
      expect(@asset_library.detail_view_whiteboards_list).to include(@whiteboard_exported.title)
    end

    it 'does not list whiteboards that use the asset but have not been exported to the asset library' do
      expect(@asset_library.detail_view_whiteboards_list).not_to include(@whiteboard_non_exported.title)
    end

    it 'does not list whiteboard assets that use the asset but have since been deleted' do
      expect(@asset_library.detail_view_whiteboards_list).not_to include(@whiteboard_deleted.title)
    end

    it 'links to the whiteboard asset detail' do
      @asset_library.click_whiteboard_usage_link(@whiteboard_exported, event)
    end
  end
end
