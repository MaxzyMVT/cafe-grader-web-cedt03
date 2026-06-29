class GroupsController < ApplicationController
  GroupMemberAction =             [:show, :edit, :update, :destroy,
                                   :show_users_query, :show_problems_query,
                                   :add_user, :add_user_by_group, :add_problem, :add_problem_by_group, :add_problem_by_tag,
                                   :toggle, :toggle_member_rename, :do_all_users, :do_user, :do_all_problems, :do_problem,
                                  ]
  before_action :stimulus_controller
  before_action :set_group, only: GroupMemberAction
  before_action :set_user, only: [:do_user]
  before_action :set_problem, only: [:do_problem]

  before_action :check_valid_login
  before_action :group_editor_authorization

  # only for member action
  before_action :can_edit_group_authorization, only: GroupMemberAction

  # GET /groups
  def index
    @groups = @current_user.groups_for_action(:edit)
  end

  def bulk_manage
    @groups = @current_user.groups_for_action(:edit).order(:name)
  end

  def bulk_manage_query
    @groups = @current_user.groups_for_action(:edit).order(:name)
    render 'bulk_manage_query'
  end

  def do_bulk_manage
    @result = []
    @error = []
    groups = get_groups_from_params.where(id: @current_user.groups_for_action(:edit).ids)

    @toast = {title: "Bulk Manage #{groups.count} #{'group'.pluralize(groups.count)}"}
    
    if params[:change_enable] == '1'
      groups.update_all(enabled: params[:enable] == 'yes')
      @result << "Set \"Enabled\" to <strong>#{params[:enable]}</strong>"
    end

    if params[:change_allow_user_change_name] == '1'
      groups.update_all(allow_user_change_name: params[:allow_user_change_name] == 'yes')
      @result << "Set \"Allow member change name\" to <strong>#{params[:allow_user_change_name]}</strong>"
    end

    @toast[:body] = "<ul> #{@result.map { |x| "<li>#{x}</li>" }.join}  </ul>".html_safe
    render 'turbo_toast'
  end

  # GET /groups/1
  def show
  end

  def show_users_query
    render json: {data: @group.groups_users.joins(:user).select(:id, :user_id, :role, :enabled, :full_name, :login, :remark)}
  end

  def show_problems_query
    # render json: {data: @group.groups_problems.joins(:problem).select(:id, :problem_id, :enabled, :name, :full_name, :date_added).order(date_added: :desc).order(:name)}
    @problems = Problem.joins(:groups_problems).where('groups_problems.group': @group).includes(:tags)
      .select(:id, 'groups_problems.enabled', 'groups_problems.problem_id', :name, :full_name, :date_added, :difficulty, :permitted_lang, :available, :view_testcase)
      .order(:number).order(:name)
  end

  # GET /groups/new
  def new
    @group = Group.new
  end

  # GET /groups/1/edit
  def edit
  end

  # POST /groups
  def create
    @group = Group.new(group_params)
    if @group.save
      redirect_to @group, notice: 'Group was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /groups/1
  def update
    if @group.update(group_params)
      redirect_to @group, notice: 'Group was successfully updated.'
    else
      render :edit
    end
  end

  def set_user_role
    GroupUser.where(user: @user, group: @group).update(role: params[:role])
    render turbo_stream: turbo_stream.replace(:user_table_frame, partial: 'group_users')
  end

  # DELETE /groups/1
  def destroy
    @group.destroy
    redirect_to groups_url, notice: 'Group was successfully destroyed.'
  end

  def toggle
    @group.update(enabled:  !@group.enabled?)
    @toast = {title: "Group #{@group.name}", body: "Enabled updated"}
    render 'toggle'
  end

  def toggle_member_rename
    @group.update(allow_user_change_name: !@group.allow_user_change_name?)
    @toast = {title: "Group #{@group.name}", body: "Members can rename group updated"}
    render 'toggle_member_rename'
  end


  # --- users & problems ---
  def do_all_users
    if params[:command] == 'enable'
      GroupUser.where(group: @group).update_all(enabled: true)
    elsif params[:command] == 'disable'
      GroupUser.where(group: @group).update_all(enabled: false)
    elsif params[:command] == 'remove'
      @group.users.clear
    else
      return
    end
  end

  # generic action for users in the group
  def do_user
    @toast = {title: "Group #{@group.name}"}
    case params[:command]
    when 'remove'
      if @user != @current_user || @user.admin?
        @group.users.delete(@user)
        @toast[:body] = "#{@user.login} was removed."
      else
        @toast[:body] = "Cannot remove yourself from the group"
        @toast[:type] = :alert
      end
    when 'toggle'
      gu = @group.groups_users.where(user: @user).first
      gu.update(enabled: !gu.enabled?)
      @toast[:body] = "User was updated."
    when 'make_editor', 'make_reporter', 'make_user'
      target_role = params[:command].split('_')[1]

      if @user != @current_user || @user.admin? || target_role == 'editor'
        GroupUser.where(user: @user, group: @group).update(role: target_role)
        @toast[:body] = "#{@user.login}'s role changed to #{target_role}."
      else
        @toast[:body] = "Cannot demote yourself"
        @toast[:type] = :alert
      end
    else
    end
    render 'turbo_toast'
  end

  def do_all_problems
    if params[:command] == 'enable'
      GroupProblem.where(group: @group).update_all(enabled: true)
    elsif params[:command] == 'disable'
      GroupProblem.where(group: @group).update_all(enabled: false)
    elsif params[:command] == 'remove'
      @group.problems.clear
    else
      return
    end
    render 'turbo_toast'
  end

  def do_problem
    case params[:command]
    when 'remove'
      @group.problems.delete(@problem)
      @toast = {title: "Group #{@group.name}", body: "Problem #{@problem.name} was removed."}
    when 'toggle'
      gp = @group.groups_problems.where(problem: @problem).first
      gp.update(enabled: !gp.enabled?)
      @toast = {title: "Group #{@group.name}", body: "The problem #{@problem.name} was updated."}
    else
    end
    render 'turbo_toast'
  end

  def add_user
    begin
      users = User.where(id: params[:user_ids]) # this find multiple users
      @toast = @group.add_users_skip_existing(users)
      render 'turbo_toast'
    rescue => e
      render partial: 'msg_modal_show', locals: {do_popup: true, header_msg: 'Adding users failed', body_msg: e.message}
    end
  end

  def add_user_by_group
    begin
      user_ids = GroupUser.where(group_id: params[:user_group_ids]).pluck :user_id
      @toast = @group.add_users_skip_existing(User.where(id: user_ids))
      render 'turbo_toast'
    rescue => e
      render partial: 'msg_modal_show', locals: {do_popup: true, header_msg: 'Adding users failed', body_msg: e.message}
    end
  end

  def add_problem
    # find return arrays of objecs
    begin
      problems = Problem.find(params[:problem_ids]) # this find multiple problems
      @group.problems << problems
      @toast = {title: "Group #{@group.name}", body: "#{problems.count} problem(s) were added."}
      render 'turbo_toast'
    rescue => e
      render partial: 'msg_modal_show', locals: {do_popup: true, header_msg: 'Adding problems failed', body_msg: e.message}
    end
  end

  def add_problem_by_group
    begin
      problem_ids = GroupProblem.where(group_id: params[:problem_group_ids]).where.not(problem_id: @group.problems.ids).pluck :problem_id
      @group.problems << Problem.where(id: problem_ids)
      @toast = {title: "Group #{@group.name}", body: "#{problem_ids.count} problems were added."}
      render 'turbo_toast'
    rescue => e
      render partial: 'msg_modal_show', locals: {do_popup: true, header_msg: 'Adding problems failed', body_msg: e.message}
    end
  end

  def add_problem_by_tag
    begin
      if params[:tag_ids].blank?
        @toast = {title: "Group #{@group.name}", body: "No tags selected.", type: :alert}
      else
        problem_ids = Problem.joins(:tags).where(tags: { id: params[:tag_ids] }).where.not(id: @group.problems.ids).pluck(:id).uniq
        @group.problems << Problem.where(id: problem_ids)
        @toast = {title: "Group #{@group.name}", body: "#{problem_ids.count} problem(s) were added."}
      end
      render 'turbo_toast'
    rescue => e
      render partial: 'msg_modal_show', locals: {do_popup: true, header_msg: 'Adding problems failed', body_msg: e.message}
    end
  end

  private
    def stimulus_controller
      @stimulus_controller = 'group'
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_group
      @group = Group.find(params[:id])
    end

    def set_user
      @user = User.find(params[:user_id]) rescue nil
    end

    def set_problem
      @problem = Problem.find(params[:problem_id]) rescue nil
    end

    def can_edit_group_authorization
      return true if @current_user.admin?
      return true if @current_user.groups_for_action(:edit).where(id: @group).any?
      unauthorized_redirect(msg: "You cannot manage group #{@group.name}.")
    end

    # Only allow a trusted parameter "white list" through.
    def group_params
      if @current_user.admin? || @current_user.problem_setter?
        params.require(:group).permit(:name, :description, :enabled, :allow_user_change_name)
      else
        params.require(:group).permit(:name, :description, :allow_user_change_name)
      end
    end

    def get_groups_from_params
      ids = params.keys.select { |k| k.start_with? 'group-' }.map { |k| k.split('-')[1].to_i }
      return Group.where(id: ids)
    end
end
