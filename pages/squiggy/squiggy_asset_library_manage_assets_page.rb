class SquiggyAssetLibraryManageAssetsPage < SquiggyAssetLibraryListViewPage

  include PageObject
  include Page
  include SquiggyPages
  include Logging

  h2(:manage_assets_heading, xpath: '//h2[text()="Manage Assets"]')

  # CUSTOM CATEGORIES

  # Create

  text_field(:add_category_input, id: 'add-category-input')
  button(:add_category_button, id: 'add-category-btn')
  div(:name_too_long_msg, xpath: '//div[text()="Category name must be 255 characters or less"]')

  def enter_category_name(name)
    wait_for_element_and_type(add_category_input_element, name)
  end

  def click_add_category_button
    wait_for_update_and_click add_category_button_element
  end

  def create_new_category(category)
    logger.info "Creating a new category called '#{category.name}'"
    sleep 1
    enter_category_name category.name
    click_add_category_button
    category.set_id
  end

  # View

  elements(:category_title, :div, class: 'v-list-item__title')
  elements(:category_usage_count, :div, class: 'v-list-item__subtitle')

  def category_row(category)
    div_element(xpath: "//div[@class='v-list-item__title'][text()='#{category.name}']")
  end

  def category_usage(category)
    div_element(id: "category-#{category.id}-asset-count").text.strip
  end

  # Edit

  def edit_category_button(category)
    button_element(id: "edit-category-#{category.id}-btn")
  end

  def edit_category_input(category)
    text_field_element(id: "edit-category-#{category.id}-input")
  end

  def edit_category_clear_button(category)
    button_element(xpath: "//input[@id='edit-category-#{category.id}-input']/../following-sibling::div//button")
  end

  def edit_category_save_button(category)
    button_element(id: "edit-category-#{category.id}-save")
  end

  def edit_category_cancel_button(category)
    button_element(id: "edit-category-#{category.id}-cancel")
  end

  def click_edit_category(category)
    wait_for_update_and_click edit_category_button(category)
  end

  def click_cancel_category_edit(category)
    wait_for_update_and_click edit_category_cancel_button(category)
    edit_category_cancel_button(category).when_not_present 2
  end

  def edit_category(category)
    logger.info "Editing category with new name '#{category.name}'"
    click_edit_category category
    wait_for_textbox_and_type(edit_category_input(category), category.name)
    wait_for_update_and_click edit_category_save_button(category)
    edit_category_save_button(category).when_not_present 2
  end

  # Delete

  def delete_category_button(category)
    button_element(id: "delete-category-#{category.id}-btn")
  end

  def delete_category(category)
    logger.info "Deleting category named '#{category.name}'"
    wait_for_update_and_click delete_category_button(category)
    wait_for_update_and_click confirm_delete_button_element
    sleep 1
    category_row(category).when_not_present 2
  end

  # CANVAS CATEGORIES

  elements(:canvas_category, :div, xpath: '//h3[text()="Assignments"]/following-sibling::div//div[@role="option"]')
  elements(:canvas_category_title, :div, xpath: '//h3[text()="Assignments"]/following-sibling::div//div[@role="option"]//div[@class="v-list-item__title"]')

  def wait_for_canvas_category(test, assignment)
    logger.info "Checking if the Canvas assignment #{assignment.title} has appeared on the Manage Categories page yet"
    tries ||= SquiggyUtils.poller_retries
    load_page test
    click_manage_assets_link
    wait_until(3) do
      canvas_category_elements.any? && (canvas_category_title_elements.map { |el| el.text.strip }).include?(assignment.title)
    end
    SquiggyUtils.set_assignment_id assignment
    logger.debug 'The assignment category has appeared'
  rescue => e
    if (tries -= 1).zero?
      fail 'Timed out waiting for assignment sync'
    else
      logger.warn "#{e.message.capitalize}. The assignment category has not yet appeared, will retry in #{Utils.short_wait} seconds"
      sleep Utils.short_wait
      retry
    end
  end

  def assignment_sync_cbx(assignment)
    checkbox_element(id: "category-#{assignment.squiggy_id}-sync-checkbox")
  end

  def enable_assignment_sync(assignment)
    logger.info "Enabling Canvas assignment sync for #{assignment.title}"
    assignment_sync_cbx(assignment).when_present Utils.short_wait
    assignment_sync_cbx(assignment).checked? ?
      logger.debug('Assignment sync is already enabled') :
      js_click(assignment_sync_cbx assignment)
  end

  def disable_assignment_sync(assignment)
    logger.info "Disabling Canvas assignment sync for #{assignment.title}"
    assignment_sync_cbx(assignment).when_present Utils.short_wait
    assignment_sync_cbx(assignment).checked? ?
      js_click(assignment_sync_cbx assignment) :
      logger.debug('Assignment sync is already disabled')
  end

end
