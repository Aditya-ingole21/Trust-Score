export function discordRoles(profile) {
  const TRUSTED_ROLES = [
    "Developer DAO",
    "Bankless",
    "Aave",
    "Morpho",
    "Base OG",
    "LayerZero"
  ];

  if (!profile || !profile.roles) {
    return { name: "Discord Roles", points: 0, max: 4 };
  }

  const hasTrustedRole = profile.roles.some(role =>
    TRUSTED_ROLES.includes(role)
  );

  return {
    name: "Discord Roles",
    points: hasTrustedRole ? 4 : 0,
    max: 4,
    matchedRoles: profile.roles.filter(r => TRUSTED_ROLES.includes(r))
  };
}
