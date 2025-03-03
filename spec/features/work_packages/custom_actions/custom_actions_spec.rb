#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe "Custom actions", :js, with_ee: %i[custom_actions] do
  shared_let(:admin) { create(:admin) }

  shared_let(:permissions) { %i(view_work_packages edit_work_packages move_work_packages work_package_assigned) }
  shared_let(:role) { create(:project_role, permissions:) }
  shared_let(:other_role) { create(:project_role, permissions:) }
  shared_let(:project) { create(:project, name: "This project") }
  shared_let(:other_project) { create(:project, name: "Other project") }
  shared_let(:user) do
    create(:user,
           firstname: "A",
           lastname: "User",
           member_with_roles: { project => [role], other_project => [role] })
  end
  shared_let(:other_member_user) do
    create(:user,
           firstname: "Other member",
           lastname: "User",
           member_with_roles: { project => role })
  end

  let!(:work_package) do
    create(:work_package,
           project:,
           assigned_to: user,
           priority: default_priority,
           status: default_status)
  end

  let(:wp_page) { Pages::FullWorkPackage.new(work_package) }
  let(:default_priority) do
    create(:default_priority, name: "Normal")
  end
  let!(:immediate_priority) do
    create(:issue_priority,
           name: "At once",
           position: IssuePriority.maximum(:position) + 1)
  end
  let(:default_status) do
    create(:default_status, name: "Default status")
  end
  let(:closed_status) do
    create(:closed_status, name: "Closed")
  end
  let(:rejected_status) do
    create(:closed_status, name: "Rejected")
  end
  let(:other_type) do
    type = create(:type)

    other_project.types << type

    type
  end
  let!(:workflows) do
    create(:workflow,
           old_status: default_status,
           new_status: closed_status,
           role:,
           type: work_package.type)

    create(:workflow,
           new_status: default_status,
           old_status: closed_status,
           role:,
           type: work_package.type)
    create(:workflow,
           old_status: default_status,
           new_status: rejected_status,
           role:,
           type: work_package.type)
    create(:workflow,
           old_status: rejected_status,
           new_status: default_status,
           role:,
           type: other_type)
  end
  let!(:list_custom_field) do
    cf = create(:list_wp_custom_field, multi_value: true)

    project.work_package_custom_fields = [cf]
    work_package.type.custom_fields = [cf]

    cf
  end
  let!(:int_custom_field) do
    create(:integer_wp_custom_field)
  end
  let(:selected_list_custom_field_options) do
    [list_custom_field.custom_options.first, list_custom_field.custom_options.last]
  end
  let!(:date_custom_field) do
    cf = create(:date_wp_custom_field)

    other_project.work_package_custom_fields = [cf]
    other_type.custom_fields = [cf]

    cf
  end
  let(:index_ca_page) { Pages::Admin::CustomActions::Index.new }

  before do
    login_as admin
  end

  # this big spec just has a different expectation when primerized_work_package_activities is enabled for the very last part
  # where the a different expectation banner would be expected
  # IMO not worth the extra computation time for the intermediate state when the feature flag is active
  it "viewing workflow buttons", with_flag: { primerized_work_package_activities: false } do
    # create custom action 'Unassign'
    index_ca_page.visit!

    new_ca_page = index_ca_page.new

    new_ca_page.set_name("Unassign")
    new_ca_page.set_description("Removes the assignee")
    new_ca_page.add_action("Assignee", "-")
    new_ca_page.expect_action("assigned_to", nil)

    new_ca_page.create

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Unassign")

    unassign = CustomAction.last
    expect(unassign.actions.length).to eq(1)
    expect(unassign.conditions.length).to eq(0)

    # create custom action 'Close'

    new_ca_page = index_ca_page.new

    new_ca_page.set_name("Close")

    new_ca_page.add_action("Status", "Close")
    new_ca_page.expect_action("status", closed_status.id)

    new_ca_page.set_condition("Role", role.name)
    new_ca_page.expect_selected_option role.name

    new_ca_page.set_condition("Status", [default_status.name, rejected_status.name])
    new_ca_page.expect_selected_option default_status.name
    new_ca_page.expect_selected_option rejected_status.name

    new_ca_page.create

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Unassign", "Close")

    close = CustomAction.last
    expect(close.actions.length).to eq(1)
    expect(close.conditions.length).to eq(2)

    # create custom action 'Escalate'

    new_ca_page = index_ca_page.new
    new_ca_page.set_name("Escalate")
    new_ca_page.add_action("Priority", immediate_priority.name)
    new_ca_page.expect_action("priority", immediate_priority.id)

    new_ca_page.add_action("Notify", other_member_user.name)

    new_ca_page.expect_selected_option other_member_user.name
    new_ca_page.add_action(list_custom_field.name, selected_list_custom_field_options.map(&:name))

    new_ca_page.expect_selected_option "A"
    new_ca_page.expect_selected_option "G"

    new_ca_page.create

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Unassign", "Close", "Escalate")

    escalate = CustomAction.last
    expect(escalate.actions.length).to eq(3)
    expect(escalate.conditions.length).to eq(0)

    # create custom action 'Reset'

    new_ca_page = index_ca_page.new

    new_ca_page.set_name("Reset")

    new_ca_page.add_action("Priority", default_priority.name)
    new_ca_page.expect_action("priority", default_priority.id)

    new_ca_page.add_action("Status", default_status.name)
    new_ca_page.expect_action("status", default_status.id)

    new_ca_page.add_action("Assignee", user.name)
    new_ca_page.expect_action("assigned_to", user.id)

    # This custom field is not applicable
    new_ca_page.add_action(int_custom_field.name, "1")
    new_ca_page.expect_action(int_custom_field.attribute_name, "1")

    new_ca_page.set_condition("Status", closed_status.name)
    new_ca_page.expect_selected_option closed_status.name

    new_ca_page.create

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Unassign", "Close", "Escalate", "Reset")

    reset = CustomAction.last
    expect(reset.actions.length).to eq(4)
    expect(reset.conditions.length).to eq(1)

    # create custom action 'Other roles action'

    new_ca_page = index_ca_page.new

    new_ca_page.set_name("Other roles action")

    new_ca_page.add_action("Status", default_status.name)
    new_ca_page.expect_action("status", default_status.id)

    new_ca_page.set_condition("Role", other_role.name)
    new_ca_page.expect_selected_option other_role.name
    new_ca_page.create

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Unassign", "Close", "Escalate", "Reset", "Other roles action")

    other_roles_action = CustomAction.last
    expect(other_roles_action.actions.length).to eq(1)
    expect(other_roles_action.conditions.length).to eq(1)

    # create custom action 'Move project'

    new_ca_page = index_ca_page.new

    retry_block do
      new_ca_page.set_name("Move project")
      # Add date custom action which has a different admin layout

      ignore_ferrum_javascript_error do
        select date_custom_field.name, from: "Add action"
      end

      ignore_ferrum_javascript_error do
        select "on", from: date_custom_field.name
      end

      date = (Date.current + 5.days)
      find("#custom_action_actions_custom_field_#{date_custom_field.id}_visible").click
      datepicker = Components::Datepicker.new "body"
      datepicker.set_date date

      new_ca_page.add_action("Type", other_type.name)
      new_ca_page.expect_action("type", other_type.id)

      new_ca_page.add_action("Project", other_project.name)
      new_ca_page.expect_action("project", other_project.id)

      new_ca_page.set_condition("Project", project.name)
      new_ca_page.expect_selected_option project.name
    end

    new_ca_page.create

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Unassign", "Close", "Escalate", "Reset", "Other roles action", "Move project")

    move_project = CustomAction.last
    expect(move_project.actions.length).to eq(3)
    expect(move_project.conditions.length).to eq(1)

    # use custom actions
    login_as(user)

    wp_page.visit!

    wp_page.expect_custom_action("Unassign")
    wp_page.expect_custom_action("Close")
    wp_page.expect_custom_action("Escalate")
    wp_page.expect_custom_action("Move project")
    wp_page.expect_no_custom_action("Reset")
    wp_page.expect_no_custom_action("Other roles action")
    wp_page.expect_custom_action_order("Unassign", "Close", "Escalate", "Move project")

    within(".custom-actions") do
      # When hovering over the button, the description is displayed
      button = find(".custom-action--button", text: "Unassign")
      expect(button["title"])
        .to eql "Removes the assignee"
    end

    wp_page.click_custom_action("Unassign")
    wp_page.expect_attributes assignee: "-"
    within ".work-package-details-activities-list" do
      expect(page)
        .to have_css(".op-user-activity .op-user-activity--user-name",
                     text: user.name,
                     wait: 10)
    end

    wp_page.click_custom_action("Escalate")
    wp_page.expect_attributes priority: immediate_priority.name,
                              status: default_status.name,
                              assignee: "-",
                              "customField#{list_custom_field.id}" => selected_list_custom_field_options.map(&:name).join("\n")
    within ".work-package-details-activities-list" do
      expect(page)
        .to have_css(".op-user-activity a.user-mention",
                     text: other_member_user.name,
                     wait: 10)
    end

    wp_page.click_custom_action("Close")
    wp_page.expect_attributes status: closed_status.name,
                              priority: immediate_priority.name

    wp_page.expect_custom_action("Reset")
    wp_page.expect_no_custom_action("Close")

    wp_page.click_custom_action("Reset")

    wp_page.expect_attributes priority: default_priority.name,
                              status: default_status.name,
                              assignee: user.name
    wp_page.expect_no_attribute "customField#{int_custom_field.id}"

    # edit 'Reset' to now be named 'Reject' which sets the status to 'Rejected'
    login_as(admin)

    index_ca_page.visit!

    edit_ca_page = index_ca_page.edit("Reset")

    retry_block do
      edit_ca_page.set_name "Reject"
      edit_ca_page.remove_action "Priority"
      edit_ca_page.set_action "Assignee", "-"
      edit_ca_page.expect_action "assigned_to", nil

      edit_ca_page.set_action "Status", rejected_status.name
      edit_ca_page.expect_action "status", rejected_status.id

      edit_ca_page.set_condition "Status", default_status.name
      edit_ca_page.expect_selected_option default_status.name
    end

    edit_ca_page.save

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Unassign", "Close", "Escalate", "Reject")

    reset = CustomAction.find_by(name: "Reject")
    expect(reset.actions.length).to eq(3)
    expect(reset.conditions.length).to eq(1)

    index_ca_page.move_top "Move project"
    index_ca_page.move_bottom "Escalate"
    index_ca_page.move_up "Close"
    index_ca_page.move_down "Unassign"

    # Check the altered button
    login_as(user)

    wp_page.visit!

    wp_page.expect_custom_action("Unassign")
    wp_page.expect_custom_action("Close")
    wp_page.expect_custom_action("Escalate")
    wp_page.expect_custom_action("Move project")
    wp_page.expect_custom_action("Reject")
    wp_page.expect_no_custom_action("Reset")
    wp_page.expect_custom_action_order("Move project", "Close", "Reject", "Unassign", "Escalate")

    wp_page.click_custom_action("Reject")
    wp_page.expect_attributes assignee: "-",
                              status: rejected_status.name,
                              priority: default_priority.name

    wp_page.expect_custom_action("Close")
    wp_page.expect_no_custom_action("Reject")

    # Delete 'Reject' from list of actions
    login_as(admin)

    index_ca_page.visit!

    index_ca_page.delete("Unassign")

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Close", "Escalate", "Reject")

    login_as(user)

    wp_page.visit!

    wp_page.expect_no_custom_action("Unassign")
    wp_page.expect_custom_action("Close")
    wp_page.expect_custom_action("Escalate")
    wp_page.expect_no_custom_action("Reject")

    # Move project
    wp_page.click_custom_action("Move project")

    wp_page.expect_attributes assignee: "-",
                              status: rejected_status.name,
                              type: other_type.name.upcase,
                              "customField#{date_custom_field.id}" => (Date.today + 5.days).strftime("%m/%d/%Y")
    expect(page)
      .to have_content(I18n.t("js.project.click_to_switch_to_project", projectname: other_project.name))

    ## Bump the lockVersion and by that force a conflict.
    work_package.reload.touch

    wp_page.click_custom_action("Escalate", expect_success: false)

    wp_page.expect_toast type: :error, message: I18n.t("api_v3.errors.code_409")
  end

  it "editing a current date custom action (Regression #30949)" do
    # create custom action 'Unassign'
    index_ca_page.visit!

    new_ca_page = index_ca_page.new

    new_ca_page.set_name("Current date")
    new_ca_page.set_description("Sets the current date")
    new_ca_page.add_action("Date", "Current date")

    new_ca_page.create

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Current date")

    date_action = CustomAction.last
    expect(date_action.actions.length).to eq(1)
    expect(date_action.conditions.length).to eq(0)

    index_ca_page.edit("Current date")
    expect(page).to have_select("custom_action_actions_date", selected: "Current date")
  end

  it "disables the custom action button and editing other fields when submiting the custom action" do
    # create custom action 'Unassign'
    index_ca_page.visit!

    new_ca_page = index_ca_page.new
    new_ca_page.set_name("Unassign")
    new_ca_page.set_description("Removes the assignee")
    new_ca_page.add_action("Assignee", "-")
    new_ca_page.expect_action("assigned_to", nil)

    new_ca_page.create

    index_ca_page.expect_current_path
    index_ca_page.expect_listed("Unassign")

    unassign = CustomAction.last
    expect(unassign.actions.length).to eq(1)
    expect(unassign.conditions.length).to eq(0)

    login_as(user)

    wp_page.visit!

    wp_page.ensure_page_loaded
    # Stop sending ajax requests in order to test disabled fields upon submit
    wp_page.disable_ajax_requests

    wp_page.click_custom_action("Unassign", expect_success: false)
    wp_page.expect_custom_action_disabled("Unassign")
    find('[data-field-name="estimatedTime"]').click
    expect(page).to have_css("#wp-#{work_package.id}-inline-edit--field-estimatedTime[disabled]")
  end

  context "with baseline enabled" do
    let(:wp_table) { Pages::WorkPackagesTable.new(project) }
    let(:query) do
      create(:query,
             name: "Timestamps Query",
             project:,
             user:,
             timestamps: ["P-1d", "PT0S"])
    end

    before do
      create(:custom_action,
             actions: [CustomActions::Actions::AssignedTo.new(value: nil)],
             name: "Unassign")
    end

    it "executes the custom action (Regression#49588)" do
      login_as(user)
      wp_table.visit_query(query)
      wp_page = wp_table.open_full_screen_by_link(work_package)

      wp_page.ensure_page_loaded

      wp_page.click_custom_action("Unassign", expect_success: true)
    end
  end
end
