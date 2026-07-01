pub const Menu = @import("screens/Menu.zig");
pub const SiteForm = @import("screens/SiteForm.zig");

pub const Screen = union(enum) {
    menu: *Menu,
    site_form: *SiteForm,
};
