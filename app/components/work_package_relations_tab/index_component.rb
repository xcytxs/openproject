# frozen_string_literal: true

# Component for rendering the relations tab content of a work package
#
# This includes:
# - Controls for adding new relations if the user has permission
# - Related work packages grouped by relation type (follows, precedes, blocks, etc.)
# - Child work packages
class WorkPackageRelationsTab::IndexComponent < ApplicationComponent
  FRAME_ID = "work-package-relations-tab-content"
  NEW_RELATION_ACTION_MENU = "new-relation-action-menu"
  I18N_NAMESPACE = "work_package_relations_tab"
  include ApplicationHelper
  include OpPrimer::ComponentHelpers
  include Turbo::FramesHelper
  include OpTurbo::Streamable

  attr_reader :work_package, :relations, :children, :directionally_aware_grouped_relations, :relation_to_scroll_to

  # Initialize the component with required data
  #
  # @param work_package [WorkPackage] The work package whose relations are being displayed
  # @param relations [Array<Relation>] The relations associated with this work package
  # @param children [Array<WorkPackage>] Child work packages
  # @param relation_to_scroll_to [Relation, WorkPackage, nil] Optional relation or child to scroll to when rendering
  def initialize(work_package:, relations:, children:, relation_to_scroll_to: nil)
    super()

    @work_package = work_package
    @relations = relations
    @children = children
    @directionally_aware_grouped_relations = group_relations_by_directional_context
    @relation_to_scroll_to = relation_to_scroll_to
  end

  def self.wrapper_key
    FRAME_ID
  end

  private

  def should_render_add_child?
    return false if @work_package.milestone?

    helpers.current_user.allowed_in_project?(:manage_subtasks, @work_package.project)
  end

  def should_render_add_relations?
    helpers.current_user.allowed_in_project?(:manage_work_package_relations, @work_package.project)
  end

  def should_render_create_button?
    should_render_add_child? || should_render_add_relations?
  end

  def group_relations_by_directional_context
    relations.group_by do |relation|
      relation.relation_type_for(work_package)
    end
  end

  def any_relations? = relations.any? || children.any?

  def render_relation_group(title:, relation_type:, items:, &_block)
    render(border_box_container(
             padding: :condensed,
             data: { test_selector: "op-relation-group-#{relation_type}" }
           )) do |border_box|
      if relation_type == :children && should_render_add_child?
        render_children_header(border_box, title, items)
      else
        render_header(border_box, title, items)
      end

      render_items(border_box, items, &_block)
    end
  end

  def render_header(border_box, title, items)
    border_box.with_header(py: 3) do
      concat render(Primer::Beta::Text.new(mr: 2, font_size: :normal, font_weight: :bold)) { title }
      concat render(Primer::Beta::Counter.new(count: items.size, round: true, scheme: :primary))
    end
  end

  def render_children_header(border_box, title, items)
    border_box.with_header(py: 3) do
      flex_layout(justify_content: :space_between, align_items: :center) do |header|
        header.with_column(mr: 2) do
          concat render(Primer::Beta::Text.new(mr: 2, font_size: :normal, font_weight: :bold)) { title }
          concat render(Primer::Beta::Counter.new(count: items.size, round: true, scheme: :primary))
        end
        header.with_column do
          render(Primer::Alpha::ActionMenu.new(menu_id: "new-child-relation")) do |menu|
            menu.with_show_button do |button|
              button.with_leading_visual_icon(icon: :plus)
              button.with_trailing_action_icon(icon: :"triangle-down")
              t("work_package_relations_tab.label_add_child_button")
            end

            render_child_items(menu)
          end
        end
      end
    end
  end

  def render_child_items(menu)
    return unless should_render_add_child?

    menu.with_item(
      label: t("work_package_relations_tab.relations.new_child"),
      href: new_project_work_packages_dialog_path(work_package.project, parent_id: work_package.id),
      content_arguments: {
        data: { turbo_stream: true }
      }
    ) do |item|
      item.with_description.with_content(t("work_package_relations_tab.relations.new_child_text"))
    end

    menu.with_item(
      label: t("work_package_relations_tab.relations.existing_child"),
      href: new_work_package_children_relation_path(work_package),
      content_arguments: {
        data: { turbo_stream: true }
      }
    ) do |item|
      item.with_description.with_content(t("work_package_relations_tab.relations.child_description"))
    end
  end

  def render_items(border_box, items)
    items.each do |item|
      border_box.with_row(
        test_selector: row_test_selector(item),
        data: data_attribute(item)
      ) do
        yield(item)
      end
    end
  end

  def data_attribute(item)
    if scroll_to?(item)
      {
        controller: "work-packages--relations-tab--scroll",
        application_target: "dynamic",
        "work-packages--relations-tab--scroll-target": "scrollToRow"
      }
    end
  end

  def scroll_to?(item)
    relation_to_scroll_to \
      && item.id == relation_to_scroll_to.id \
      && item.instance_of?(relation_to_scroll_to.class)
  end

  def new_relation_path(relation_type:)
    raise ArgumentError, "Invalid relation type: #{relation_type}" unless Relation::TYPES.key?(relation_type)

    if relation_type == Relation::TYPE_CHILD
      raise NotImplementedError, "Child relations are not supported yet"
    else
      new_work_package_relation_path(work_package, relation_type:)
    end
  end

  def new_button_test_selector(relation_type:)
    "op-new-relation-button-#{relation_type}"
  end

  def row_test_selector(item)
    related_work_package_id = find_related_work_package_id(item)
    "op-relation-row-#{related_work_package_id}"
  end

  def find_related_work_package_id(item)
    if item.is_a?(Relation)
      item.from_id == work_package.id ? item.to_id : item.from_id
    else
      item.id
    end
  end
end
