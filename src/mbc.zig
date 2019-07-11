pub const Mbc = struct {
    cart: []u8,

    pub fn load(self: *Mbc, cart: []u8) void {
        self.cart = cart;
    }

    // TODO: remove me
    pub fn ptr(self: Mbc, addr: u16) [*]u8 {
        return self.cart.ptr + addr;
    }

    pub fn get(self: Mbc, addr: u16) u8 {
        return cart[addr];
    }

    pub fn set(self: *Mbc, addr: u16, val: u8) void {}
};
