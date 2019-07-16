require_relative '../../util/spec_helper'

class BOACFilteredCohortPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewPages
  include BOACCohortPages
  include BOACGroupModalPages
  include BOACAddGroupSelectorPages

  def filtered_cohort_base_url(id)
    "#{BOACUtils.base_url}/cohort/#{id}"
  end

  # Loads the cohort page by the cohort's ID
  # @param cohort [FilteredCohort]
  def load_cohort(cohort)
    logger.info "Loading cohort '#{cohort.name}'"
    navigate_to(filtered_cohort_base_url(cohort.id))
    wait_for_title cohort.name
  end

  # Hits a cohort URL and expects the 404 page to load
  # @param cohort [FilteredCohort]
  def hit_non_auth_cohort(cohort)
    navigate_to filtered_cohort_base_url(cohort.id)
    wait_for_title 'Page not found'
  end

  # FILTERED COHORTS - Creation

  button(:save_cohort_button_one, id: 'save-button')
  text_area(:cohort_name_input, id: 'create-input')
  button(:save_cohort_button_two, id: 'create-confirm')
  button(:cancel_cohort_button, id: 'create-cancel')
  elements(:everyone_cohort_link, :link, xpath: '//h1[text()="Everyone\'s Cohorts"]/following-sibling::div//a')

  # Clicks the button to save a new cohort, which triggers the name input modal
  def click_save_cohort_button_one
    wait_until(Utils.medium_wait) { save_cohort_button_one_element.enabled? }
    wait_for_update_and_click save_cohort_button_one_element
  end

  # Enters a cohort name and clicks the Save button
  # @param cohort [FilteredCohort]
  def name_cohort(cohort)
    wait_for_element_and_type(cohort_name_input_element, cohort.name)
    wait_for_update_and_click save_cohort_button_two_element
  end

  # Clicks the Save Cohort button, enters a cohort name, and clicks the Save button
  # @param cohort [FilteredCohort]
  def save_and_name_cohort(cohort)
    click_save_cohort_button_one
    name_cohort cohort
  end

  # Waits for a cohort page to load and obtains the cohort's ID
  # @param cohort [FilteredCohort]
  # @return [Integer]
  def wait_for_filtered_cohort(cohort)
    cohort_heading(cohort).when_present Utils.medium_wait
    BOACUtils.set_filtered_cohort_id cohort
  end

  # Clicks the Cancel button during cohort creation
  def cancel_cohort
    wait_for_update_and_click cancel_cohort_button_element
    modal_element.when_not_present Utils.short_wait
  rescue
    logger.warn 'No cancel button to click'
  end

  # Creates a new cohort
  # @param cohort [FilteredCohort]
  def create_new_cohort(cohort)
    logger.info "Creating a new cohort named #{cohort.name}"
    save_and_name_cohort cohort
    wait_for_filtered_cohort cohort
  end

  # Combines methods to load the create filtered cohort page, perform a search, and create a filtered cohort
  # @param cohort [FilteredCohort]
  # @param test [BOACTestConfig]
  def search_and_create_new_cohort(cohort, test)
    click_sidebar_create_filtered
    perform_search(cohort, test)
    create_new_cohort cohort
  end

  # Loads the Everyone's Cohorts page
  def load_everyone_cohorts_page
    navigate_to "#{BOACUtils.base_url}/cohorts/all"
    wait_for_title 'Cohorts'
  end

  # Returns all the cohorts displayed on the Everyone's Cohorts page
  # @return [Array<FilteredCohort>]
  def visible_everyone_cohorts
    click_view_everyone_cohorts
    wait_for_spinner
    begin
      wait_until(Utils.short_wait) { everyone_cohort_link_elements.any? }
      cohorts = everyone_cohort_link_elements.map { |link| FilteredCohort.new({id: link.attribute('href').gsub("#{BOACUtils.base_url}/cohort/", ''), name: link.text}) }
    rescue
      cohorts = []
    end
    cohorts.flatten!
    logger.info "Visible Everyone's Cohorts are #{cohorts.map &:name}"
    cohorts
  end

  # FILTERED COHORTS - Search

  button(:show_filters_button, xpath: "//button[contains(.,'Show Filters')]")
  # The 'new_filter_button' xpath uses 'starts-with' because third-party Bootstrap-Vue dynamically appends an id-suffix.
  button(:new_filter_button, xpath: '//button[starts-with(@id, \'new-filter-button\')]')
  button(:new_sub_filter_button, xpath: '//div[contains(@id,"filter-row-dropdown-secondary")]//button')
  elements(:new_filter_option, :link, class: 'dropdown-item')
  elements(:new_filter_initial_input, :text_area, class: 'filter-range-input')
  button(:unsaved_filter_add_button, id: 'unsaved-filter-add')
  button(:unsaved_filter_cancel_button, id: 'unsaved-filter-reset')
  button(:unsaved_filter_apply_button, id: 'unsaved-filter-apply')

  # Returns a filter option link with given text, used to find options other than 'Advisor'
  # @param option_name [String]
  # @return [PageObject::Elements::Link]
  # @deprecated Use <tt>new_filter_option_by_key</tt> instead
  def new_filter_option(option_name)
    link_element(xpath: "//a[contains(.,\"#{option_name}\")]")
  end

  # Returns a filter option link with given text. Element id is based on filter key, not filter label.
  # @param option_key [String]
  # @return [PageObject::Elements::Link]
  def new_filter_option_by_key(option_key)
    link_element(id: "dropdown-primary-menuitem-#{option_key}-new")
  end

  # Returns a filter option list item with given text, used to find 'Advisor' options
  # @param advisor_uid [String]
  # @return [PageObject::Elements::ListItem]
  def new_filter_advisor_option(advisor_uid)
    link_element(id: "Advisor-#{advisor_uid}")
  end

  def sub_option_element(filter_name, filter_option)
    link_attribute = case filter_name
                       when 'Advisor'
                         "@id='Advisor-#{filter_option}'"
                       when 'Major'
                         "@id='Major-#{filter_option}'"
                       when 'Team'
                         squad = Squad::SQUADS.find { |s| s.name == filter_option }
                         "@id='Team-#{squad.code}'"
                       else
                         "text()=\"#{filter_option}\""
                     end
    button_element(xpath: "//a[#{link_attribute}]/../../preceding-sibling::button")
  end

  # Selects a sub-category for a filter type that offers sub-categories
  # @param filter_name [String]
  # @param filter_option [String]
  # @deprecated Use <tt>choose_sub_option_by_key</tt> instead
  def choose_sub_option(filter_name, filter_option)
    # Last Name requires input
    if filter_name == 'Last Name'
      wait_for_element_and_type(new_filter_initial_input_elements[0], filter_option.split[0])
      wait_for_element_and_type(new_filter_initial_input_elements[1], filter_option.split[1])
    # All others require a selection
    else
      wait_for_update_and_click new_sub_filter_button_element
      option_element = case filter_name
                         when 'Advisor'
                           new_filter_advisor_option(filter_option)
                         when 'Major'
                           link_element(xpath: "//a[@id=\"Major-#{filter_option}\"]")
                         when 'Expected Graduation Term'
                           link_element(xpath: "//a[@id='Expected Graduation Term-#{filter_option}']")
                         else
                           link_element(xpath: "//div[@class=\"cohort-filter-draft-column-02\"]//a[contains(.,\"#{filter_option}\")]")
                       end
      wait_for_update_and_click option_element
    end
  end

  # Selects a sub-category for a filter type that offers sub-categories
  # @param filter_key [String]
  # @param filter_option [String]
  def choose_sub_option_by_key(filter_key, filter_option)
    # Last Name requires input
    if filter_key == 'lastNameRange'
      wait_for_element_and_type(new_filter_initial_input_elements[0], filter_option.split[0])
      wait_for_element_and_type(new_filter_initial_input_elements[1], filter_option.split[1])
      # All others require a selection
    else
      wait_for_update_and_click new_sub_filter_button_element
      option_element = if filter_key == 'coeAdvisorLdapUids'
                         new_filter_advisor_option(filter_option)
                       else
                        link_element(xpath: "//div[@class=\"cohort-filter-draft-column-02\"]//a[contains(.,\"#{filter_option}\")]")
                       end
      wait_for_update_and_click option_element
    end
  end

  # Clicks the new filter button, making two attempts in case of a DOM update
  def click_new_filter_button
    wait_for_update_and_click new_filter_button_element
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    wait_for_update_and_click new_filter_button_element
  end

  # Selects, adds, and applies a filter
  # @param filter_name [String]
  # @param filter_option [String]
  def select_filter(filter_name, filter_option = nil)
    logger.info "Selecting #{filter_name} #{filter_option}"
    click_new_filter_button
    wait_for_update_and_click new_filter_option(filter_name)

    # Inactive, Intensive, Probation, Underrepresented Minority, Transfer Student have no sub-options
    unless ['Transfer Student', 'Inactive', 'Inactive (COE)', 'Inactive (ASC)', 'Intensive', 'Underrepresented Minority', 'Probation'].include? filter_name
      choose_sub_option(filter_name, filter_option)
    end
    wait_for_update_and_click unsaved_filter_add_button_element
    unsaved_filter_apply_button_element.when_present Utils.short_wait
  end

  # Selects, adds, and applies a filter
  # @param filter_key [String]
  # @param filter_option [String]
  def select_filter_by_key(filter_key, filter_option = nil)
    logger.info "Selecting #{filter_key} #{filter_option}"
    click_new_filter_button
    wait_for_update_and_click new_filter_option_by_key(filter_key)

    # Inactive, Intensive, Probation, and Underrepresented Minority have no sub-options
    choose_sub_option_by_key(filter_key, filter_option) unless %w(isInactiveAsc isInactiveCoe inIntensiveCohort underrepresented coeProbation).include? filter_key
    wait_for_update_and_click unsaved_filter_add_button_element
    unsaved_filter_apply_button_element.when_present Utils.short_wait
  end

  # Returns the heading for a given cohort page
  # @param cohort [FilteredCohort]
  # @return [PageObject::Elements::Span]
  def cohort_heading(cohort)
    h1_element(xpath: "//h1[contains(text(),\"#{cohort.name}\")]")
  end

  # Ensures that cohort filters are visible
  def show_filters
    button_element(id: 'show-hide-details-button').when_visible Utils.medium_wait
    show_filters_button if show_filters_button?
  end

  elements(:cohort_filter_row, :div, class: 'filter-row')

  # Returns the XPath to the filter name on a filter row
  # @param filter_name [String]
  # @return [String]
  def filter_xpath(filter_name)
    "//div[contains(@class,\"filter-row\")]/div[contains(.,\"#{filter_name}\")]"
  end

  # Returns the element containing an added cohort filter
  # @param filter_option [String]
  # @return [PageObject::Elements::Element]
  def existing_filter_element(filter_name, filter_option = nil)
    filter_option_xpath = "#{filter_xpath filter_name}/following-sibling::div"
    if ['Intensive', 'Inactive', 'Inactive (ASC)', 'Inactive (COE)', 'Underrepresented Minority'].include? filter_name
      div_element(xpath: filter_xpath(filter_name))
    elsif filter_name == 'Last Name'
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{filter_option.split.join(' through ')}\")]")
    else
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{filter_option}\")]")
    end
  end

  # Verifies that a cohort's filters are visibly selected
  # @param cohort [FilteredCohort]
  def verify_filters_present(cohort)
    if cohort.search_criteria.list_filters.flatten.compact.any?
      show_filters
      wait_until(Utils.short_wait) { cohort_filter_row_elements.any? }
      filters = cohort.search_criteria
      wait_until(5) do
        filters.gpa.each { |g| existing_filter_element('GPA', g).exists? } if filters.gpa && filters.gpa.any?
        filters.level.each { |l| existing_filter_element('Level', l).exists? } if filters.level && filters.level.any?
        filters.units_completed.each { |u| existing_filter_element('Units Completed', u).exists? } if filters.units_completed && filters.units_completed.any?
        filters.major.each { |m| existing_filter_element('Major', m).exists? } if filters.major && filters.major.any?
        existing_filter_element('Transfer Student').exists? if filters.transfer_student
        filters.expected_grad_terms.each { |t| existing_filter_element('Expected Graduation Term', t).exists? } if filters.expected_grad_terms && filters.expected_grad_terms.any?
        existing_filter_element('Last Name', filters.last_name).exists? if filters.last_name
        # TODO - advisors
        filters.coe_ethnicity.each { |e| existing_filter_element('Ethnicity (COE)', e).exists? } if filters.coe_ethnicity && filters.coe_ethnicity.any?
        filters.gender.each { |g| existing_filter_element('Gender (COE)', g).exists? } if filters.coe_gender && filters.coe_gender.any?
        existing_filter_element('Underrepresented Minority').exists? if filters.underrepresented_minority
        filters.prep.each { |p| existing_filter_element('PREP', p).exists? } if filters.prep && filters.prep.any?
        existing_filter_element('Probation').exists? if filters.probation_coe
        existing_filter_element('Inactive').exists? if filters.inactive_asc
        existing_filter_element('Intensive').exists? if filters.intensive_asc
        filters.team.each { |t| existing_filter_element('Team', t.name).exists? } if filters.team && filters.team.any?
        true
      end
    else
      unsaved_filter_apply_button_element.when_not_visible Utils.short_wait
      wait_until(1) { cohort_filter_row_elements.empty? }
    end
  end

  # Returns the XPath to the Edit, Cancel, and Update controls for a filter row
  # @param filter_name [String]
  # @return [String]
  def filter_controls_xpath(filter_name)
    "#{filter_xpath filter_name}/following-sibling::div[2]"
  end

  # Edits the first filter of a given type
  # @param filter_name [String]
  # @param new_filter_option [String]
  def edit_filter_of_type(filter_name, new_filter_option)
    wait_for_update_and_click button_element(xpath: "#{filter_controls_xpath filter_name}//button[contains(.,'Edit')]")
    choose_sub_option(filter_name, new_filter_option)
  end

  # Clicks the cancel button for the first filter of a given type that is in edit mode
  # @param filter_name [String]
  def cancel_filter_edit(filter_name)
    el = button_element(xpath: "#{filter_controls_xpath filter_name}//button[contains(.,'Cancel')]")
    wait_for_update_and_click el
    el.when_not_present 1
  end

  # Clicks the update button for the first filter of a given type that is in edit mode
  # @param filter_name [String]
  def confirm_filter_edit(filter_name)
    el = button_element(xpath: "#{filter_controls_xpath filter_name}//button[contains(.,'Update')]")
    wait_for_update_and_click el
    el.when_not_present 1
  end

  # Saves an edit to the first filter of a given type
  # @param filter_name [String]
  # @param filter_option [String]
  def edit_filter_and_confirm(filter_name, filter_option)
    logger.info "Changing '#{filter_name}' to '#{filter_option}'"
    edit_filter_of_type(filter_name, filter_option)
    confirm_filter_edit(filter_name)
  end

  # Removes the first filter of a given type
  # @param filter_name [String]
  def remove_filter_of_type(filter_name)
    logger.info "Removing '#{filter_name}'"
    row_count = cohort_filter_row_elements.length
    wait_for_update_and_click button_element(xpath: "#{filter_controls_xpath filter_name}//button[contains(.,'Remove')]")
    wait_until(Utils.short_wait) { cohort_filter_row_elements.length == row_count - 1 }
  end

  # Waits for a search to complete and returns the count of results.
  # @return [Integer]
  def wait_for_search_results
    wait_for_spinner
    results_count
  end

  # Executes a custom cohort search using search criteria associated with a cohort and stores the result count
  # @param cohort [FilteredCohort]
  # @param test [BOACTestConfig]
  def perform_search(cohort, test)

    # The squads and majors lists can change over time. Avoid test failures if the search criteria is out of sync
    # with actual squads or majors. Advisors might also change, but fail if this happens for now.
    if cohort.search_criteria.major && cohort.search_criteria.major.any?
      click_new_filter_button
      wait_for_update_and_click new_filter_option_by_key('majors')
      wait_for_update_and_click new_sub_filter_button_element
      sleep Utils.click_wait
      filters_missing = []
      cohort.search_criteria.major.each { |major| filters_missing << major unless sub_option_element('Major', major).exists? }
      logger.debug "The majors #{filters_missing} are not present, removing from search criteria" if filters_missing.any?
      filters_missing.each { |f| cohort.search_criteria.major.delete f }
      wait_for_update_and_click unsaved_filter_cancel_button_element
    end
    if cohort.search_criteria.team && cohort.search_criteria.team.any?
      wait_for_update_and_click new_filter_button_element
      wait_for_update_and_click new_filter_option_by_key('groupCodes')
      wait_for_update_and_click new_sub_filter_button_element
      sleep 2
      filters_missing = []
      cohort.search_criteria.team.each { |squad| filters_missing << squad unless sub_option_element('Team', squad.name).exists? }
      logger.debug "The squads #{filters_missing} are not present, removing from search criteria" if filters_missing.any?
      filters_missing.each { |f| cohort.search_criteria.team.delete f }
      wait_for_update_and_click unsaved_filter_cancel_button_element
    end

    # Global
    cohort.search_criteria.gpa.each { |g| select_filter_by_key('gpaRanges', g) } if cohort.search_criteria.gpa
    cohort.search_criteria.level.each { |l| select_filter_by_key('levels', l) } if cohort.search_criteria.level
    cohort.search_criteria.units_completed.each { |u| select_filter_by_key('unitRanges', u) } if cohort.search_criteria.units_completed
    cohort.search_criteria.major.each { |m| select_filter_by_key('majors', m) } if cohort.search_criteria.major
    select_filter 'Transfer Student' if cohort.search_criteria.transfer_student
    cohort.search_criteria.expected_grad_terms.each { |t| select_filter('Expected Graduation Term', t) } if cohort.search_criteria.expected_grad_terms
    select_filter('Last Name', cohort.search_criteria.last_name) if cohort.search_criteria.last_name

    # CoE
    cohort.search_criteria.advisor.each { |a| select_filter_by_key('coeAdvisorLdapUids', a) } if cohort.search_criteria.advisor
    cohort.search_criteria.coe_ethnicity.each { |e| select_filter_by_key('coeEthnicities', e) } if cohort.search_criteria.coe_ethnicity
    select_filter 'Underrepresented Minority' if cohort.search_criteria.underrepresented_minority
    cohort.search_criteria.coe_gender.each { |g| select_filter_by_key('coeGenders', g) } if cohort.search_criteria.coe_gender
    cohort.search_criteria.prep.each { |p| select_filter_by_key('coePrepStatuses', p) } if cohort.search_criteria.prep
    select_filter 'Probation' if cohort.search_criteria.probation_coe
    inactive_label = (test.dept == BOACDepartments::ADMIN) ? 'Inactive (COE)' : 'Inactive'
    select_filter inactive_label if cohort.search_criteria.inactive_coe

    # ASC
    select_filter_by_key 'isInactiveAsc' if cohort.search_criteria.inactive_asc
    select_filter_by_key 'inIntensiveCohort' if cohort.search_criteria.intensive_asc
    cohort.search_criteria.team.each { |s| select_filter('Team', s.name) } if cohort.search_criteria.team

    # If there are any search criteria left, execute search and log time search took to complete
    if cohort.search_criteria.list_filters.flatten.compact.any?
      wait_for_update_and_click unsaved_filter_apply_button_element
      cohort.member_count = wait_for_search_results
      logger.warn "No results found for #{cohort.search_criteria.list_filters}" if cohort.member_count.zero?
    # If no search criteria remain, do not try to search
    else
      logger.warn 'None of the search criteria are available in the UI'
      cohort.member_count = 0
    end
  end

  # Filters an array of user data hashes according to search criteria and returns the users that should be present in the UI after
  # the search completes
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def expected_search_results(test, search_criteria)

    # GPA
    matching_gpa_users = []
    if search_criteria.gpa && search_criteria.gpa.any?
      search_criteria.gpa.each do |range|
        array = range.include?('Below') ? %w(0 2.0) : range.delete(' ').split('-')
        low_end = array[0]
        high_end = array[1]
        matching_gpa_users << test.searchable_data.select do |u|
          if u[:gpa]
            gpa = u[:gpa].to_f
            (gpa != 0) && (low_end.to_f <= gpa) && ((high_end == '4.00') ? (gpa <= high_end.to_f.round(1)) : (gpa < high_end.to_f.round(1)))
          end
        end
      end
    else
      matching_gpa_users = test.searchable_data
    end
    matching_gpa_users.flatten!

    # Level
    matching_level_users = if search_criteria.level && search_criteria.level.any?
                             test.searchable_data.select do |u|
                               search_criteria.level.find { |search_level| search_level.include? u[:level] } if u[:level]
                             end
                           else
                             test.searchable_data
                           end

    # Units
    matching_units_users = []
    if search_criteria.units_completed
      search_criteria.units_completed.each do |units|
        if units.include?('+')
          matching_units_users << test.searchable_data.select { |u| u[:units_completed].to_f >= 120 if u[:units_completed] }
        else
          range = units.split(' - ')
          low_end = range[0].to_f
          high_end = range[1].to_f
          matching_units_users << test.searchable_data.select { |u| (u[:units_completed].to_f >= low_end) && (u[:units_completed].to_f < high_end.round(-1)) }
        end
      end
    else
      matching_units_users = test.searchable_data
    end
    matching_units_users.flatten!

    # Major
    matching_major_users = []
    (search_criteria.major && search_criteria.major.any?) ?
        (matching_major_users << test.searchable_data.select { |u| (u[:major] & search_criteria.major).any? }) :
        (matching_major_users = test.searchable_data)
    matching_major_users = matching_major_users.uniq.flatten.compact

    # Transfer Student
    matching_tranfer_users = (search_criteria.transfer_student ? (test.searchable_data.select { |u| u[:transfer_student] }) : test.searchable_data)

    # Expected Graduation Term
    matching_grad_term_users = if search_criteria.expected_grad_terms && search_criteria.expected_grad_terms.any?
                                 test.searchable_data.select do |u|
                                   search_criteria.expected_grad_terms.find { |search_term| search_term == u[:expected_grad_term] }
                                 end
                               else
                                 test.searchable_data
                               end
    matching_grad_term_users.flatten!

    # Last Name
    matching_last_name_users = if search_criteria.last_name
                                 test.searchable_data.select { |u| u[:last_name_sortable_cohort][0] >= search_criteria.last_name.split[0].downcase && u[:last_name_sortable_cohort][0] <= search_criteria.last_name.split[1].downcase }
                               else
                                 test.searchable_data
                               end

    # Advisor
    matching_advisor_users = (search_criteria.advisor && search_criteria.advisor.any?) ?
        (test.searchable_data.select { |u| search_criteria.advisor.include? u[:advisor] }) : test.searchable_data

    # Ethnicity (COE)
    matching_coe_ethnicity_users = []
    if search_criteria.coe_ethnicity && search_criteria.coe_ethnicity.any?
      search_criteria.coe_ethnicity.each do |coe_ethnicity|
        matching_coe_ethnicity_users << test.searchable_data.select { |u| search_criteria.coe_ethnicity(u[:coe_ethnicity]) == coe_ethnicity }
      end
    else
      matching_coe_ethnicity_users = test.searchable_data
    end
    matching_coe_ethnicity_users.flatten!

    # Underrepresented Minority
    matching_minority_users = search_criteria.underrepresented_minority ? (test.searchable_data.select { |u| u[:underrepresented_minority] }) : test.searchable_data

    # Gender (COE)
    matching_coe_gender_users = []
    if search_criteria.coe_gender && search_criteria.coe_gender.any?
      search_criteria.coe_gender.each do |coe_gender|
        if coe_gender == 'Male'
          matching_coe_gender_users << test.searchable_data.select { |u| %w(M m).include? u[:coe_gender] }
        elsif coe_gender == 'Female'
          matching_coe_gender_users << test.searchable_data.select { |u| %w(F f).include? u[:coe_gender] }
        else
          logger.error "Test data has an unrecognized COE gender '#{coe_gender}'"
          fail
        end
      end
    else
      matching_coe_gender_users = test.searchable_data
    end
    matching_coe_gender_users.flatten!

    # PREP
    matching_preps_users = []
    if search_criteria.prep && search_criteria.prep.any?
      search_criteria.prep.each do |prep|
        matching_preps_users << test.searchable_data.select { |u| u[:prep] } if prep == 'PREP'
        matching_preps_users << test.searchable_data.select { |u| u[:prep_elig] } if prep == 'PREP eligible'
        matching_preps_users << test.searchable_data.select { |u| u[:t_prep] } if prep == 'T-PREP'
        matching_preps_users << test.searchable_data.select { |u| u[:t_prep_elig] } if prep == 'T-PREP eligible'
      end
    else
      matching_preps_users = test.searchable_data
    end
    matching_preps_users.flatten!

    # Inactive COE
    matching_inactive_coe_users = search_criteria.inactive_coe ? (test.searchable_data.select { |u| u[:inactive_coe] }) : test.searchable_data

    # Probation COE
    matching_probation_asc_users = search_criteria.probation_coe ? (test.searchable_data.select { |u| u[:probation_coe] }) : test.searchable_data

    # Inactive ASC
    matching_inactive_asc_users = search_criteria.inactive_asc ? (test.searchable_data.reject { |u| u[:active_asc] }) : test.searchable_data

    # Intensive ASC
    matching_intensive_asc_users = search_criteria.intensive_asc ? (test.searchable_data.select { |u| u[:intensive_asc] }) : test.searchable_data

    # Team
    matching_squad_users = (search_criteria.team && search_criteria.team.any?) ?
        (test.searchable_data.select { |u| (u[:squad_names] & (search_criteria.team.map { |s| s.name })).any? }) :
        test.searchable_data

    matches = [matching_gpa_users, matching_level_users, matching_units_users, matching_major_users, matching_tranfer_users,
               matching_grad_term_users, matching_last_name_users, matching_advisor_users, matching_coe_ethnicity_users, matching_minority_users,
               matching_coe_gender_users, matching_preps_users, matching_inactive_coe_users, matching_probation_asc_users,
               matching_inactive_asc_users, matching_intensive_asc_users, matching_squad_users]
    matches.any?(&:empty?) ? [] : matches.inject(:'&')
  end

  # FILTERED COHORTS - Management

  text_area(:rename_cohort_input, id: 'rename-cohort-input')

  # Renames a cohort
  # @param cohort [FilteredCohort]
  # @param new_name [String]
  def rename_cohort(cohort, new_name)
    logger.info "Changing the name of cohort ID #{cohort.id} to #{new_name}"
    load_cohort cohort
    wait_for_load_and_click rename_cohort_button_element
    cohort.name = new_name
    wait_for_element_and_type(rename_cohort_input_element, new_name)
    wait_for_update_and_click rename_cohort_confirm_button_element
    h1_element(xpath: "//h1[contains(text(),\"#{cohort.name}\")]").when_present Utils.short_wait
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by first name
  # @param expected_users [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_first_name(expected_users)
    sorted_users = expected_users.sort_by { |u| [u[:first_name_sortable_cohort].downcase, u[:last_name_sortable_cohort].downcase, u[:sid]] }
    sorted_users.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by last name
  # @param expected_users [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_last_name(expected_users)
    sorted_users = expected_users.sort_by { |u| [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_users.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by team
  # @param expected_users [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_team(expected_users)
    players = []
    non_players = []
    expected_users.each { |u| u[:squad_names].any? ? (players << u) : (non_players << u) }
    # Students with no teams come after those with teams
    sorted_players = players.sort_by { |u| [u[:squad_names].sort.first.gsub(' (AA)', '') .gsub(/\W+/, ''), u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_non_players = non_players.sort_by { |u| [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_users = sorted_players + sorted_non_players
    sorted_users.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by GPA
  # @param expected_users [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_gpa(expected_users)
    sorted_users = expected_users.sort_by { |u| [u[:gpa].to_f, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_users.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by level
  # @param expected_users [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_level(expected_users)
    # Sort first by the secondary sort order
    users_by_first_name = expected_users.sort_by { |u| [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    # Then arrange by the sort order for level
    users_by_level = []
    %w(Freshman Sophomore Junior Senior Graduate).each do |level|
      users_by_level << users_by_first_name.select do |u|
        u[:level] == level
      end
    end
    users_by_level.flatten.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by major
  # @param expected_users [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_major(expected_users)
    sorted_users = expected_users.sort_by { |u| [u[:major].sort.first.gsub(/\W/, '').downcase, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_users.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by cumulative units
  # @param expected_users [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_units(expected_users)
    sorted_users = expected_users.sort_by { |u| [u[:units_completed].to_f, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_users.map { |u| u[:sid] }
  end

end
