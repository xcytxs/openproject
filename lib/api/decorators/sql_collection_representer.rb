#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2022 the OpenProject GmbH
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

module API
  module Decorators
    class SqlCollectionRepresenter
      include API::Decorators::Sql::Hal

      class << self
        def ctes(walker_result)
          {
            projection: walker_result.projection_scope.limit(sql_limit(walker_result)).offset(sql_offset(walker_result)).to_sql,
            total: walker_result.filter_scope.reselect('COUNT(*)').except(:order).to_sql
          }
        end

        private

        def select_from(walker_result)
          "projection"
        end

        def full_self_path(walker_results, overrides = {})
          "#{walker_results.self_path}?#{href_query(walker_results, overrides)}"
        end

        def href_query(walker_results, overrides)
          query_params = walker_results.url_query.merge(overrides)

          if (select_params = query_params.delete(:select))
            query_params[:select] = select_href_params(select_params).flatten.join(',')
          end

          # Embedding is not supported yet but parts of the functionality is already in place.
          query_params.delete(:embed)

          query_params.to_query
        end

        # Turns the nested values for select and embed into the external representation
        # of a comma separated string. E.g.
        # { '*' => {}, 'elements' => { '*' => {} } }
        # is turned into
        # '*,elements/*'
        def select_href_params(params)
          params.map do |key, value|
            if value.empty?
              key
            else
              select_href_params(value).map do |sub_value|
                "#{key}/#{sub_value}"
              end
            end
          end
        end
      end

      property :_type,
               representation: ->(*) { "'Collection'" }

      property :count,
               representation: ->(*) { "COUNT(*)" }

      property :total,
               representation: ->(*) { "(SELECT * from total)" }

      property :pageSize,
               representation: ->(walker_result) { walker_result.page_size }

      property :offset,
               representation: ->(walker_result) { walker_result.offset }

      link :self,
           href: ->(walker_result) { "'#{full_self_path(walker_result)}'" },
           title: -> {}

      link :jumpTo,
           href: ->(walker_result) { "'#{full_self_path(walker_result, offset: '{offset}')}'" },
           title: -> {},
           templated: true

      link :changeSize,
           href: ->(walker_result) { "'#{full_self_path(walker_result, pageSize: '{size}')}'" },
           title: -> {},
           templated: true

      link :previousByOffset,
           href: ->(walker_result) { "'#{full_self_path(walker_result, offset: walker_result.offset - 1)}'" },
           render_if: ->(walker_result) { walker_result.offset > 1 },
           title: -> {}

      link :nextByOffset,
           href: ->(walker_result) { "'#{full_self_path(walker_result, offset: walker_result.offset + 1)}'" },
           render_if: ->(walker_result) { "#{walker_result.offset * walker_result.page_size} < (SELECT * FROM total)" },
           title: -> {}

      embedded :elements,
               representation: ->(walker_result) do
                 replacement = walker_result.replace_map['elements']

                 replacement ? "json_agg(#{replacement})" : nil
               end
    end
  end
end
