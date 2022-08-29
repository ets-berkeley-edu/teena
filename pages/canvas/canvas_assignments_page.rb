require_relative '../../util/spec_helper'

module Page

  class CanvasAssignmentsPage < CanvasPage

    include PageObject
    include Logging
    include Page

    # Loads the assignments page for a given course site
    # @param course [Course]
    def load_page(course)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/assignments"
    end

    # ASSIGNMENT CREATION

    link(:new_assignment_link, text: 'Assignment')
    link(:edit_assignment_link, class: 'edit_assignment_link')
    select_list(:assignment_type, id: 'assignment_submission_type')
    text_area(:assignment_name, id: 'assignment_name')
    text_area(:assignment_due_date, class: 'DueDateInput')
    checkbox(:online_url_cbx, id: 'assignment_online_url')
    checkbox(:online_upload_cbx, id: 'assignment_online_upload')
    checkbox(:online_text_entry_cbx, id: 'assignment_text_entry')
    checkbox(:online_media_cbx, id: 'assignment_media_recording')
    button(:save_assignment_button, xpath: '//button[contains(.,"Save")]')
    h1(:assignment_title_heading, class: 'title')

    # Begins creating a new assignment, entering title and scrolling to the submission types
    # @param course [Course]
    # @param assignment [Assignment]
    def enter_new_assignment_title(course, assignment)
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/assignments/new"
      assignment_name_element.when_visible Utils.medium_wait
      assignment_name_element.send_keys assignment.title
      wait_for_element_and_type_js(assignment_due_date_element, assignment.due_date.strftime("%b %-d %Y")) unless assignment.due_date.nil?
      scroll_to_element assignment_type_element
      online_url_cbx_element.when_visible Utils.short_wait
    end

    # Saves and publishes an assignment and returns its URL
    # @param assignment [Assignment]
    # @return [String]
    def save_and_publish_assignment(assignment)
      click_save_and_publish
      published_button_element.when_visible Utils.medium_wait
      logger.info "Submission assignment URL is #{current_url}"
      assignment.url = current_url
      assignment.id = assignment.url.split('/').last
      assignment.url
    end

    def create_assignment(course, assignment)
      logger.info "Creating submission assignment named '#{assignment.title}'"
      enter_new_assignment_title(course, assignment)
      check_online_url_cbx
      check_online_upload_cbx
      save_and_publish_assignment assignment
    end

    # Creates a non-sync-able assignment on a course site
    # @param course [Course]
    # @param assignment [Assignment]
    def create_unsyncable_assignment(course, assignment)
      logger.info "Creating unsyncable assignment named '#{assignment.title}'"
      enter_new_assignment_title(course, assignment)
      uncheck_online_url_cbx
      uncheck_online_upload_cbx
      check_online_text_entry_cbx
      check_online_media_cbx
      save_and_publish_assignment assignment
    end

    def edit_assignment_title(assignment)
      navigate_to assignment.url
      wait_for_load_and_click edit_assignment_link_element
      wait_for_element_and_type(assignment_name_element, (assignment.title = "#{assignment.title} - Edited"))
      wait_for_update_and_click_js save_assignment_button_element
      wait_until(Utils.short_wait) { assignment_title_heading_element.exists? && assignment_title_heading.include?(assignment.title) }
    end

    # ASSIGNMENT SUBMISSION

    button(:submit_assignment_button, xpath: '//button[text()="Start Assignment"]')
    button(:resubmit_assignment_button, xpath: '//button[text()="Re-submit Assignment"]')
    link(:assignment_file_upload_tab, class: 'submit_online_upload_option')
    button(:upload_file_button, xpath: '//button[contains(., "Upload File")]')
    text_field(:file_upload_input, name: 'attachments[0][uploaded_data]')
    button(:file_upload_submit_button, id: 'submit_file_button')
    link(:assignment_site_url_tab, class: 'submit_online_url_option')
    text_area(:url_upload_input, id: 'submission_url')
    button(:url_upload_submit_button, xpath: '(//button[@type="submit"])[2]')
    div(:assignment_submission_conf, xpath: '//div[contains(.,"Submitted!")]')

    def upload_assignment(submission)
      if submission.file_name
        wait_for_update_and_click upload_file_button_element
        file_upload_input_element.when_visible Utils.short_wait
        self.file_upload_input_element.send_keys SquiggyUtils.asset_file_path(submission.file_name)
        wait_for_update_and_click_js file_upload_submit_button_element
      else
        wait_for_update_and_click_js assignment_site_url_tab_element
        url_upload_input_element.when_visible Utils.short_wait
        self.url_upload_input = submission.url
        wait_for_update_and_click_js url_upload_submit_button_element
      end
    end

    def submit_assignment(assignment, user, submission)
      logger.info "Submitting #{submission.title} for #{user.full_name}"
      navigate_to assignment.url
      wait_for_load_and_click_js submit_assignment_button_element
      assignment_submission_conf_element.when_visible Utils.long_wait
    end

    def resubmit_assignment(assignment, user, resubmission)
      logger.info "Resubmitting #{resubmission.title} for #{user.full_name}"
      navigate_to assignment.url
      wait_for_load_and_click_js resubmit_assignment_button_element
      upload_assignment(resubmission)
      resubmit_assignment_button_element.when_visible Utils.long_wait
    end

    # ASSIGNMENT METADATA

    elements(:list_view_assignment, :link, xpath: '//li[contains(@class, "assignment")]/div[contains(@id, "assignment_")]')
    div(:assignment_submission_details_section, xpath: '//div[contains(.,"Submission Details:")]')
    link(:assignment_submission_details_link, xpath: '//a[contains(.,"Submission Details")]')
    span(:assignment_submission_date, xpath: '//h2[text()="Submission"]/following-sibling::div[@class="content"]/span')
    div(:assignment_submission_grade, xpath: '//h2[text()="Submission"]//div[contains(.,"Grade: ")]')
    link(:quiz_attempt_1_link, xpath: '//a[contains(text(),"Attempt 1")]')
    div(:quiz_submitted_msg, xpath: '//div[@class="quiz_score"]/following-sibling::div[contains(.,"Submitted")]')

    # Loads the list view assignments page for a course
    # @param course [Course]
    def load_list_view_assignments(course)
      # Get all the assignments in list view
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/assignments"
      begin
        wait_until(Utils.short_wait) { list_view_assignment_elements.any? }
      rescue => e
        logger.error "#{e.message + "\n"}"
        logger.warn "There are no assignments for course ID #{course.site_id}"
      end

      # Pause to avoid stale element errors
      sleep Utils.short_wait
    end

    # Returns the first visible assignment
    # @return [Assignment]
    def first_visible_list_view_assignment
      id = list_view_assignment_elements.first.attribute('data-item-id')
      title = link_element(xpath: '//li[contains(@class, "assignment")]/div[contains(@id, "assignment_")]//a').text.strip
      Assignment.new(id: id, title: title)
    end

    # Returns the Assignments visible on list view
    # @return [Array<Assignment>]
    def get_list_view_assignments(course)
      load_list_view_assignments course
      list_view_assignment_elements.map do |el|
        id = el.attribute('id').gsub('assignment_', '')
        assignment_xpath = "//div[@id='assignment_#{id}']"
        url = "#{Utils.canvas_base_url}/courses/#{course.site_id}/assignments/#{id}"
        title = link_element(xpath: "#{assignment_xpath}//a").text.strip
        type = 'roll-call' if title.include? 'Roll Call'

        # Due date and/or score (meaning submitted) are sometimes present on list view
        due_date_xpath = "#{assignment_xpath}//div[contains(@class, 'assignment-date-due')]/span"
        if span_element(xpath: due_date_xpath).exists?
          due_date = DateTime.parse span_element(xpath: due_date_xpath).text.strip.gsub('at', '')
        end

        score_xpath = "#{assignment_xpath}//span[@class='score-display']"
        if span_element(xpath: score_xpath).exists?
          # If a grade exists, consider it submitted
          submitted = (grading = span_element(xpath: "#{assignment_xpath}//span[@class='grade-display']")).exists? && grading.visible? && !grading.text.include?('Incomplete')
          # If no grade exists but a non-null and non-zero score exists, consider it submitted
          unless submitted
            submitted = span_element(xpath: score_xpath).visible? &&
                        !span_element(xpath: score_xpath).text.include?('-/') &&
                        (span_element(xpath: "#{score_xpath}/b").text != '0' if span_element(xpath: "#{score_xpath}/b").exists?)
          end
        end

        Assignment.new({:id => id, :type => type, :title => title, :url => url, :due_date => due_date, :submitted => submitted})
      end
    end

    # Loads the assignment detail page
    # @param assign [Assignment]
    def load_assignment_detail(assign)
      navigate_to assign.url
      sleep 1
      h1_element(xpath: '//h1').when_visible Utils.short_wait
    end

    link(:manage_assignment_link, xpath: '//a[contains(., "Manage Assignment")]')
    link(:delete_assignment_link, xpath: '//a[contains(@class, "delete_assignment_link")]')

    # Deletes all assignments with 'QA Test' in the title
    # @param assignments [Array<Assignment>]
    def delete_test_assignments(assignments)
      test_assignments = assignments.select { |a| a.title.include? Utils.get_test_id.gsub(/\d+/, '') }
      test_assignments.each do |a|
        wait_for_update_and_click div_element(xpath: "//button[@id='assign_#{a.id}_manage_link']/..")
        alert { wait_for_update_and_click_js link_element(id: "assignment_#{a.id}_settings_delete_item") }
        sleep Utils.short_wait
      end
    end

  end
end
