module ActsAsFollower #:nodoc:
  module Followable

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def acts_as_followable
        has_many :followings, :as => :followable, :dependent => :destroy, :class_name => 'Follow'
        include ActsAsFollower::Followable::InstanceMethods
        include ActsAsFollower::FollowerLib
      end
    end

    module InstanceMethods

      def all_followers_by_type(follower_type)
        follower_type.constantize.joins(:follows).
          where('follows.followable_id'   => self.id, 
                'follows.followable_type' => parent_class_name(self), 
                'follows.follower_type'   => follower_type)
      end

      # Returns the number of followers a record has.
      def followers_count
        self.followings.unblocked.confirmed.count
      end

      # Returns the followers by a given type
      def followers_by_type(follower_type, options={})
        follows = follower_type.constantize.
          joins(:follows).
          where('follows.blocked'         => false,
                'follows.unconfirmed'     => false,
                'follows.followable_id'   => self.id, 
                'follows.followable_type' => parent_class_name(self), 
                'follows.follower_type'   => follower_type)
        if options.has_key?(:limit)
          follows = follows.limit(options[:limit])
        end
        if options.has_key?(:includes)
          follows = follows.includes(options[:includes])
        end
        follows
      end

      # Return all the followers of a given type unconfirmed confirmation
      def followers_by_type_unconfirmed(follower_type, options={})
        follows = follower_type.constantize.
          joins(:follows).
          where('follows.blocked'         => false,
                'follows.unconfirmed'     => true,
                'follows.followable_id'   => self.id, 
                'follows.followable_type' => parent_class_name(self), 
                'follows.follower_type'   => follower_type)
        if options.has_key?(:limit)
          follows = follows.limit(options[:limit])
        end
        if options.has_key?(:includes)
          follows = follows.includes(options[:includes])
        end
        follows
      end

      # Return all the followers of a given type with rights
      def followers_by_type_with_rights(class_name, options={})
        self.followers_by_type(class_name, options).where(:"follows.has_rights" => true)
      end

      def followers_by_type_count(follower_type)
        self.followings.unblocked.confirmed.for_follower_type(follower_type).count
      end

      # Allows magic names on followers_by_type
      # e.g. user_followers == followers_by_type('User')
      # Allows magic names on followers_by_type_count
      # e.g. count_user_followers == followers_by_type_count('User')
      def method_missing(m, *args)
        if m.to_s[/count_(.+)_followers/]
          followers_by_type_count($1.singularize.classify)
        elsif m.to_s[/(.+)_followers_with_rights/]
          followers_by_type_with_rights($1.singularize.classify)
        elsif m.to_s[/unconfirmed_(.+)_followers/]
          followers_by_type_unconfirmed($1.singularize.classify)
        elsif m.to_s[/all_(.+)_followers/]
          all_followers_by_type($1.singularize.classify)
        elsif m.to_s[/(.+)_followers/]
          followers_by_type($1.singularize.classify)
        else
          super
        end
      end

      def blocked_followers_count
        self.followings.blocked.count
      end

      def unconfirmed_followers_count
        self.followings.unconfirmed.count
      end

      # Returns the following records.
      def followers(options={})
        self.followings.unblocked.confirmed.includes(:follower).all(options).collect{|f| f.follower}
      end

      # Returns all the followers with rights
      def followers_with_rights(options={})
        self.followings.unblocked.confirmed.with_rights.includes(:follower).all(options).collect{|f| f.follower}
      end

      # Returns all the followers with rights
      def followers_unconfirmed(options={})
        self.followings.unblocked.unconfirmed.with_rights.includes(:follower).all(options).collect{|f| f.follower}
      end

      def blocks(options={})
        self.followings.blocked.includes(:follower).all(options).collect{|f| f.follower}
      end

      # Returns true if the current instance is followed by the passed record
      # Returns false if the current instance is blocked by the passed record or no follow is found
      def followed_by?(follower)
        self.followings.unblocked.confirmed.for_follower(follower).exists?
      end

      # Returns true if the passed follower has rights in the current instance.
      def has_rights?(follower)
        self.followings.unblocked.confirmed.with_rights.for_follower(follower).exists?
      end

      def block(follower)
        get_follow_for(follower) ? block_existing_follow(follower) : block_future_follow(follower)
      end

      def unblock(follower)
        get_follow_for(follower).try(:delete)
      end

      # Confirm a follower to be fully member of the club
      def confirm(follower)
        self.followings.unblocked.for_follower(follower).first.try(:update_attribute, :unconfirmed, false)
      end

      # Give rights to a follower
      def give_rights(follower)
        self.followings.unblocked.confirmed.for_follower(follower).first.try(:update_attribute, :has_rights, true)
      end

      # Remove rights from a follower
      def remove_rights(follower)
        self.followings.unblocked.confirmed.for_follower(follower).first.try(:update_attribute, :has_rights, false)
      end

      def get_follow_for(follower)
        self.followings.for_follower(follower).first
      end

      private

      def block_future_follow(follower)
        follows.create(:followable => self, :follower => follower, :blocked => true)
      end

      def block_existing_follow(follower)
        get_follow_for(follower).block!
      end

    end

  end
end
