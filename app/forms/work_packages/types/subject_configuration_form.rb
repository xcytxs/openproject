# frozen_string_literal: true

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

module WorkPackages
  module Types
    class SubjectConfigurationForm < ApplicationForm
      class << self
        def has_pattern?(type)
          type.replacement_pattern_defined_for?(:subject)
        end
      end

      form do |subject_form|
        subject_form.radio_button_group(name: :subject_configuration) do |group|
          group.radio_button(
            value: "manual",
            checked: !has_pattern?,
            label: I18n.t("types.edit.subject_configuration.manually_editable_subjects.label"),
            caption: I18n.t("types.edit.subject_configuration.manually_editable_subjects.caption"),
            data: { action: "admin--subject-configuration#hidePatternInput" }
          )
          group.radio_button(
            value: "auto",
            checked: has_pattern?,
            label: I18n.t("types.edit.subject_configuration.automatically_generated_subjects.label"),
            caption: I18n.t("types.edit.subject_configuration.automatically_generated_subjects.caption"),
            disabled: !EnterpriseToken.active? && !has_pattern?,
            data: { action: "admin--subject-configuration#showPatternInput" }
          )
        end

        subject_form.group(data: { "admin--subject-configuration-target": "patternInput" }) do |toggleable_group|
          toggleable_group.text_field(
            name: :subject_pattern,
            value: subject_pattern,
            label: I18n.t("types.edit.subject_configuration.pattern.label"),
            caption: I18n.t("types.edit.subject_configuration.pattern.caption"),
            required: true,
            input_width: :large
          )
        end

        subject_form.submit(
          name: :submit,
          label: I18n.t(:button_save),
          disabled: !EnterpriseToken.active? && !has_pattern?,
          scheme: :primary
        )
      end

      private

      def has_pattern?
        self.class.has_pattern?(model)
      end

      def subject_pattern
        return "" if model.patterns.subject.nil?

        model.patterns.subject.blueprint
      end
    end
  end
end
