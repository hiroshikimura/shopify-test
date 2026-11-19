# frozen_string_literal: true

# 通信ログビューア。アクセストークン等を含みうるので、トンネル越しではなくローカルからのみ見られるようにしている
class LogsController < ApplicationController
  before_action :require_local_request

  def index
    @logs = CommunicationLog.recent.limit(200)
    @logs = @logs.where(direction: params[:direction]) if params[:direction].present?
    @logs = @logs.where(category: params[:category]) if params[:category].present?
  end

  def show
    @log = CommunicationLog.find(params[:id])
  end

  def destroy_all
    CommunicationLog.delete_all
    redirect_to(logs_path, notice: "ログを削除しました")
  end

  private

  def require_local_request
    head(:forbidden) unless request.local?
  end
end
