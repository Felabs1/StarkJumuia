use starknet::ContractAddress;
use core::array::{Array, ArrayTrait};
use starknet::class_hash::ClassHash;

#[starknet::interface]
pub trait IStarkZuriContract<TContractState> {
    fn add_user(ref self: TContractState, name: felt252, username: felt252, profile_pic: ByteArray, cover_photo: ByteArray);
    fn view_user(self: @TContractState, user_id: ContractAddress) -> User;
    fn view_user_count(self: @TContractState) -> u256;
    fn view_all_users(self: @TContractState) -> Array<User>;
    fn follow_user(ref self: TContractState, user: ContractAddress);
    fn follower_exist(self: @TContractState, user: ContractAddress) -> bool;
    fn view_followers(self: @TContractState, user: ContractAddress) -> Array<User>;
    fn upgrade(ref self: TContractState, impl_hash: ClassHash);
    fn version(self: @TContractState) -> u256;

}

#[derive(Drop, Serde, starknet::Store)]
pub struct User {
    pub userId: ContractAddress,
    pub name: felt252,
    pub username: felt252,
    pub profile_pic: ByteArray,
    pub cover_photo: ByteArray,
    pub date_registered: felt252,
    pub no_of_followers: u8,
    pub number_following: u8,
}


#[derive(Drop, Serde, starknet::Store)]
pub struct Post {
    #[key]
    postId: u8,
    caller: ContractAddress,
    content: ByteArray,
    likes: u8,
    comments: u8,
    shares: u8,
    //images: ByteArray,
    // images and video links will be stored in Legacy Maps for now
}


#[starknet::contract]
pub mod StarkZuri {
    // importing dependancies into the starknet contract;

    use core::traits::Into;
use starknet::{ContractAddress, get_caller_address};
    use starknet::class_hash::ClassHash;
    use starknet::SyscallResultTrait;
    use core::num::traits::Zero;
    use super::User;
    use super::Post;
    #[storage]
    struct Storage {
        deployer: ContractAddress,
        version: u256,
        users_count: u256,
        users: LegacyMap::<ContractAddress, User>,
        posts: LegacyMap::<(ContractAddress, u8), Post>,
        user_addresses: LegacyMap::<u256, ContractAddress>,
        // followers and following profiles
        followers: LegacyMap::<(ContractAddress, u8), ContractAddress>,
        post_comments: LegacyMap::<(ContractAddress, u8), felt252>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let deployer = get_caller_address();
        self.deployer.write(deployer);
    }

    #[event]
    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Upgraded: Upgraded
    }

    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Upgraded {
        pub implementation: ClassHash
    }

    // adding user to or better still veryfying you ruser details
    #[abi(embed_v0)]
    impl StarkZuri of super::IStarkZuriContract<ContractState> {
        fn add_user(ref self: ContractState, name: felt252, username: felt252, profile_pic: ByteArray, cover_photo: ByteArray) {
            let caller: ContractAddress = get_caller_address();
            let user: User = User {
                userId: caller,
                name: name,
                username: username,
                profile_pic: profile_pic,
                cover_photo: cover_photo,
                date_registered: 'now',
                no_of_followers: 0,
                number_following: 0,
            };
            let available_user = self.view_user(caller);
            if(available_user.userId != caller) {
                let assigned_user_number: u256 = self.users_count.read() + 1;

                self.users.write(caller, user);
                self.users_count.write(assigned_user_number);
                self.user_addresses.write(assigned_user_number, caller);
            }
            
        }

        fn view_user(self: @ContractState, user_id: ContractAddress) -> User {
            let user = self.users.read(user_id);
            user
        }

        fn view_user_count(self: @ContractState) -> u256 {
            self.users_count.read()
        }

        fn view_all_users(self: @ContractState)->Array<User> {
            let mut users: Array = ArrayTrait::new();
            let mut counter: u256 = 1;
            let user_length = self.users_count.read();
            while(counter <= user_length){
                let user_address: ContractAddress = self.user_addresses.read(counter);
                let single_user: User = self.users.read(user_address);
                users.append(single_user);
                counter += 1;
            };

            users
        }

        fn follow_user(ref self: ContractState, user: ContractAddress){
            let mut user_following: ContractAddress = get_caller_address();
            // the person doing the following
            let mut _user: User = self.users.read(user_following);
            
            // let us check if the caller allready followed the user so we dont have to update again
            // let available_follower = self.followers.read((user, ))
            // this is the person being followed
            let mut user_to_be_followed: User = self.users.read(user);
            let mut _user_to_be_followed: User = self.users.read(user);
            if self.follower_exist(user) == false {
                user_to_be_followed.no_of_followers += 1;
                _user_to_be_followed.no_of_followers += 1;
                _user.number_following += 1;
                self.users.write(user_following, _user);
                self.users.write(user, _user_to_be_followed);

                self.followers.write(
                    (user, user_to_be_followed.no_of_followers), 
                 user_following);
            }
            
        }

        fn follower_exist(self: @ContractState, user: ContractAddress) -> bool {
            let mut user_to_be_followed: User = self.users.read(user);
            let no_of_follwers = user_to_be_followed.no_of_followers;
            let mut counter = 1;
            let mut follower_exist = false;
            while(counter <= no_of_follwers){
                let follower = self.followers.read((user, counter));
                if(follower == get_caller_address()) {
                    follower_exist = true;
                    break;
                }
                counter+=1;
            };
            follower_exist
        }

        fn view_followers(self: @ContractState, user: ContractAddress) -> Array<User>{
            let mut followers: Array = ArrayTrait::new();
            let mut counter: u8 = 1;
            let user_followed:User = self.users.read(user);
            let no_of_followers = user_followed.no_of_followers;

            while (counter <= no_of_followers) {
                let _follower_address: ContractAddress = self.followers.read((user, counter));
                let _follower: User = self.users.read(_follower_address);
                followers.append(_follower);
                counter += 1;
            };

            followers
        }

        fn upgrade(ref self: ContractState, impl_hash: ClassHash) {
            let upgrader = get_caller_address();
            assert(impl_hash.is_non_zero(), 'class hash cannot be zero');
            assert(self.deployer.read() == upgrader, 'only felix can upgrade');
            starknet::syscalls::replace_class_syscall(impl_hash).unwrap_syscall();
            self.emit(Event::Upgraded(Upgraded {implementation: impl_hash}));
            self.version.write(self.version.read() + 1);
        }

        fn version(self: @ContractState) -> u256 {
            self.version.read()
        }
        

    }

}

