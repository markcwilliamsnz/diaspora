#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require File.join(Rails.root, 'lib/em-webfinger')

class RequestsController < ApplicationController
  before_filter :authenticate_user!
  include RequestsHelper

  respond_to :html

  def destroy
    if params[:accept]
      if params[:aspect_id]
        @friend = current_user.accept_and_respond( params[:id], params[:aspect_id])
        flash[:notice] = I18n.t 'requests.destroy.success'
        respond_with :location => current_user.aspect_by_id(params[:aspect_id])
      else
        flash[:error] = I18n.t 'requests.destroy.error'
        respond_with :location => requests_url
      end
    else
      current_user.ignore_friend_request params[:id]
      flash[:notice] = I18n.t 'requests.destroy.ignore'
      respond_with :location => requests_url
    end
  end

  def new
    @request = Request.new
  end

  def create
    aspect = current_user.aspect_by_id(params[:request][:aspect_id])
    account = params[:request][:destination_url].strip  
    
    EM::next_tick { 
      finger = EMWebfinger.new(account)

      finger.on_person{ |person|
        rel_hash = {:friend => person}

        Rails.logger.debug("Sending request: #{rel_hash}")

        begin
          @request = current_user.send_friend_request_to(rel_hash[:friend], aspect)
          
        rescue Exception => e
          raise e unless e.message.include? "already"
          flash[:notice] = I18n.t 'requests.create.already_friends', :destination_url => params[:request][:destination_url]
        end

        if @request
          flash[:notice] =  I18n.t 'requests.create.success',:destination_url => @request.destination_url
        else
          flash[:error] = I18n.t 'requests.create.horribly_wrong'
        end
      end
    }
    
    finger.fetch
  }
  flash[:notice] = "we tried our best to send a message to #{account}"
  redirect_to aspects_manage_path
  end

end
