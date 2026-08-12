# Single source of truth for AC zone metadata. Plain data file, NOT a module.
# Imported by automations.nix / sensors.nix / templates.nix / utility-meters.nix.
[
  {
    slug = "sala";
    friendly = "Sala";
    eco = 19;
    comfort = 21;
    boost = 22;
  }
  {
    slug = "escritorio";
    friendly = "Escritorio";
    eco = 19;
    comfort = 21;
    boost = 22;
  }
  {
    slug = "quarto";
    friendly = "Quarto";
    eco = 17;
    comfort = 19;
    boost = 20;
  }
  {
    slug = "quarto_hospedes";
    # friendly must slugify back to slug: generated sensor/template entities are
    # named from `friendly`, while automations/utility-meters reference `slug`.
    # "Hospedes" slugifies to "hospedes" (orphaning them); "Quarto Hospedes"
    # slugifies to "quarto_hospedes".
    friendly = "Quarto Hospedes";
    eco = 17;
    comfort = 20;
    boost = 21;
  }
]
