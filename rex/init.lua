-- Rex configuration (managed in ~/dotfiles/rex/init.lua)
-- Trust pi OSC 7577 Program Resume reports (`pi --session <uuid>`).
rex.set("resume.trust.pi", {
  command = { "pi", "--session", rex.match.uuid },
})
