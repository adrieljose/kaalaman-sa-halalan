# -*- coding: utf-8 -*-
"""The v3 rotations: each character rotated from its OWN existing sprite.

`create_character(mode="v3", reference_image_*)` re-draws a sprite you already
have into 8 directions instead of inventing a new character, which is what
makes this a repose rather than a redesign -- the reference defines identity.

Two directions matter for battle, and they are the reason this was worth doing:
    south-west  the rival's 3/4 facing LEFT, toward the player
    south-east  the player's 3/4 facing RIGHT, toward the rival
Both keep the face, eyes and props visible, where a flat profile does not.
"""
ACCOUNT = "dd0f26b2-d5b5-44dd-8fa3-990efafabf9f"

# slug -> (character id, signed token)
ROTATED = {
    "juan":           ("b3da2ecf-4e42-4f8b-8e62-4659b597fe5e", "1788013311"),
    "maria":          ("e4c53403-a0df-46ae-b30e-93bfaa5301cd", None),
    "fixer_fredo":    ("c912cd5d-19f8-4991-b24f-6ae0180c53f3", None),
    "clerk_kurakot":  ("ecf149ee-fce8-461c-bc39-ec2310380ed0", None),
    "permit_peke":    ("04da19aa-964f-4d45-969d-7f5462a4c48c", None),
    "notaryo_naku":   ("dadc4125-d740-42f3-b64d-64a90730bc85", None),
    "cashier_kaltas": ("e4e6a119-a4c7-4825-9cb1-430aecc466ec", None),
    "budget_bandido": ("e1e4150c-85bc-44cd-b76a-439978d9e2f0", None),
    "ordinance_ogre": ("04aa5b5a-af1b-4184-939e-162a30918745", None),
    "bidding_bandit": ("6551b8ad-406a-43cf-ad54-84302a072db8", None),
    "don_eraptado":   ("9e1643fa-fc24-4fc5-b6cf-5bbd271b3c27", None),
}

# The rival faces the player; the player faces the rival.
FACING = {"juan": "south-east", "maria": "south-east"}
DEFAULT_FACING = "south-west"
