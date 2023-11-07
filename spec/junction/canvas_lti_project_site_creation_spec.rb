require_relative '../../util/spec_helper'

standalone = ENV['STANDALONE']

describe 'bCourses project site', order: :defined do

  include Logging

  test = JunctionTestConfig.new
  test.projects
  project = Course.new({})

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @site_creation_page = Page::JunctionPages::CanvasSiteCreationPage.new @driver
    @create_project_site_page = Page::JunctionPages::CanvasCreateProjectSitePage.new @driver
    @find_person_to_add_page = Page::JunctionPages::CanvasCourseAddUserPage.new @driver
    @official_sections_page = Page::JunctionPages::CanvasCourseManageSectionsPage.new @driver

    if standalone
      @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
    else
      @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
      @canvas.masquerade_as test.manual_teacher
    end
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'information' do

    before(:all) do
      standalone ? @site_creation_page.load_standalone_tool : @site_creation_page.load_embedded_tool(test.manual_teacher)
    end

    it 'shows a link to project site help' do
      title = 'bCourses Project Sites | Research, Teaching, and Learning'
      expect(@site_creation_page.external_link_valid?(@site_creation_page.project_help_link_element, title)).to be true
    end

    it 'shows a link to info about other collaboration tools' do
      @site_creation_page.switch_to_canvas_iframe
      title = 'Collaboration Services | bConnected'
      expect(@site_creation_page.external_link_valid?(@site_creation_page.projects_learn_more_link_element, title)).to be true
    end

  end

  describe 'creation' do

    it 'requires that a site name be no more than 255 characters' do
      standalone ? @site_creation_page.load_standalone_tool : @site_creation_page.load_embedded_tool(test.manual_teacher)
      @site_creation_page.click_create_project_site
      @create_project_site_page.create_project_site "#{'A loooooong title' * 15}?"
      @create_project_site_page.name_too_long_msg_element.when_present Utils.short_wait
    end

    it 'allows a user to create a project site' do
      @site_creation_page.load_embedded_tool test.manual_teacher
      @site_creation_page.click_create_project_site
      @create_project_site_page.create_project_site(project.title = "QA Project Site #{Time.now}")
      @canvas.wait_until(Utils.medium_wait) { @canvas.current_url.include? "#{Utils.canvas_base_url}/courses" }
      project.site_id = @canvas.current_url.delete "#{Utils.canvas_base_url}/courses/"
      logger.info "Project site ID is #{project.site_id}"
      @canvas.switch_to_main_content
      expect(@canvas.course_site_heading).to eql("#{project.title}") unless standalone
    end

    unless standalone
      it('redirects to a custom project homepage') { @canvas.project_site_heading_element.when_present Utils.short_wait }
      it('does not add the Official Sections tool') { expect(@official_sections_page.official_sections_link?).to be false }
    end
  end

  describe 'user roles' do

    unless standalone
      it 'include Owner, Maintainer, and Member in the Add People tool' do
        @canvas.load_users_page project
        @canvas.wait_for_load_and_click @canvas.add_people_button_element
        @canvas.wait_for_update_and_click @canvas.user_role_element
        logger.debug "Available user roles are '#{@canvas.user_role_option_elements.map &:text}'"
        expect((@canvas.user_role_option_elements.map(&:text) & %w(Owner Maintainer Member)).length == 3).to be true
      end
    end

    %w(Owner Maintainer Member).each do |user_role|

      it "include '#{user_role}' in the Find a Person to Add tool" do
        user = User.new({uid: Utils.oski_uid, role: user_role})
        @find_person_to_add_page.load_embedded_tool project
        @find_person_to_add_page.search(Utils.oski_uid, 'CalNet UID')
        @find_person_to_add_page.add_user_by_uid user
        @find_person_to_add_page.success_msg_element.when_visible Utils.short_wait
      end
    end
  end

  unless standalone
    describe 'user role restrictions' do

      [test.ta, test.staff, test.students.first].each do |user|

        it "allows #{user.role} UID #{user.uid} to see a Create a Site button if permitted to do so" do
          @canvas.masquerade_as user
          @canvas.load_homepage
          has_create_site_button = @canvas.verify_block { @canvas.create_site_link_element.when_visible(Utils.short_wait) }
          (%w(TA Staff).include? user.role) ?
              (expect(has_create_site_button).to be true) :
              (expect(has_create_site_button).to be false)
        end

        it "allows #{user.role} UID #{user.uid} to navigate to the tool if permitted to do so" do
          @canvas.masquerade_as user
          @site_creation_page.load_embedded_tool user

          case user.role
            when 'TA'
              logger.debug "Verifying that #{user.role} UID #{user.uid} has access to the project site UI"
              @site_creation_page.click_create_project_site
              expect(@create_project_site_page.site_name_input_element.when_present Utils.short_wait).to be_truthy
            when 'Staff'
              logger.debug "Verifying that #{user.role} UID #{user.uid} has access to the project site UI but not the course site UI"
              @site_creation_page.click_create_project_site
              expect(@create_project_site_page.site_name_input_element.when_present Utils.short_wait).to be_truthy
            else
              logger.debug "Verifying that #{user.role} UID #{user.uid} has access to neither the course nor the project site UIs"
              @site_creation_page.create_course_site_link_element.when_present Utils.short_wait
              expect(@site_creation_page.create_project_site_link_element.attribute('disabled')).to eql('true')
          end
        end
      end
    end
  end
end
