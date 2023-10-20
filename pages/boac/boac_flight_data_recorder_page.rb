class BOACFlightDataRecorderPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  def load_page(dept)
    logger.info "Hitting the FDR page for #{dept.name}"
    navigate_to "#{BOACUtils.base_url}/analytics/#{dept.code}"
  end

  select_list(:dept_select, id: 'available-department-reports')
  h2(:dept_heading, xpath: '(//h2)[2]')
  button(:show_hide_report_button, id: 'show-hide-notes-report')
  h3(:notes_count_boa, xpath: '//h3[contains(text(), " notes have been created in BOA")]')
  div(:notes_count_boa_authors, id: 'notes-count-boa-authors')
  div(:notes_count_boa_with_attachments, id: 'notes-count-boa-with-attachments')
  div(:notes_count_boa_with_topics, id: 'notes-count-boa-with-topics')
  div(:notes_count_sis, id: 'notes-count-sis')
  div(:notes_count_asc, id: 'notes-count-asc')
  div(:notes_count_ei, id: 'notes-count-ei')

  # Returns the total BOA note count
  # @return [String]
  def boa_note_count
    notes_count_boa_element.text.gsub('notes have been created in BOA', '').strip
  end

  # Filters the advisor report by a given department
  # @param dept [BOACDepartments]
  def select_dept_report(dept)
    logger.info "Selecting report for #{dept.code}"
    wait_for_element_and_select(dept_select_element, dept.code)
    sleep 3
  end

  # Returns the available departments in the advisor report filter
  # @return [Array<String>]
  def dept_select_option_values
    dept_select_element.options.map { |el| el.attribute('value') }
  end

  # Clicks the show/hide button for the BOA notes report
  def toggle_note_report_visibility
    logger.info 'Clicking the show/hide report button'
    wait_for_update_and_click show_hide_report_button_element
  end

  elements(:advisor_link, :link, xpath: '//a[contains(@id, "directory-link-")]')
  elements(:advisor_non_link, :span, xpath: '//span[contains(text(), "Name unavailable (UID:")]')

  # Returns all the UIDs in an advisor result set
  # @return [Array<String>]
  def list_view_uids
    sleep 3
    tries = 2
    begin
      tries -= 1
      wait_until(Utils.medium_wait) { advisor_link_elements.any? }
      links = advisor_link_elements.map { |el| el.attribute('id').split('-').last }
      non_links = advisor_non_link_elements.map { |el| el.text.split.last.delete(")") }
      links + non_links
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      if tries.zero?
        logger.error 'DOM update error'
        fail
      else
        logger.warn 'DOM update caused an error, retrying'
        retry
      end
    end
  end

  # Returns the element corresponding to a given user's role in a given department
  # @param advisor [BOACUser]
  # @param dept [BOACDepartments]
  # @return [Element]
  def advisor_role(advisor, dept)
    span_element(id: "dept-#{dept.code}-#{advisor.uid}").text
  end

  # Returns the visible note count for a given advisor
  # @param advisor [BOACUser]
  # @return [String]
  def advisor_note_count(advisor)
    row_xpath = if link_element(id: "directory-link-#{advisor.uid}").exists?
                  "//a[@id='directory-link-#{advisor.uid}']"
                else
                  "//span[text()='Name unavailable (UID: #{advisor.uid})']"
                end
    div_element(xpath: "#{row_xpath}//ancestor::td/following-sibling::td[@data-label='Notes Created']/div").text
  end

  # Returns the visible last login date for a given advisor
  # @param advisor [BOACUser]
  # @return [String]
  def advisor_last_login(advisor)
    div_element(id: "user-last-login-#{advisor.uid}").text
  end

end
