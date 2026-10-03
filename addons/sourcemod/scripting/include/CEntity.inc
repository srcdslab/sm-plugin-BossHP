#if defined _class_centity_
#endinput
#endif
#define _class_centity_

// Non-boss entity with health, displayed on the HUD when a player damages it
methodmap CEntity < Basic
{
	public CEntity()
	{
		Basic myclass = new Basic();

		myclass.SetInt("iRef", INVALID_ENT_REFERENCE);
		myclass.SetString("sName", "");
		myclass.SetBool("bActive", false);
		myclass.SetFloat("fLastHitTime", GetGameTime());

		return view_as<CEntity>(myclass);
	}

	public bool GetName(char[] buffer, int length)
	{
		return this.GetString("sName", buffer, length);
	}

	public void SetName(const char[] buffer)
	{
		this.SetString("sName", buffer);
	}

	// Entity reference, use EntRefToEntIndex() to get the entity index
	property int iRef {
		public get() { return this.GetInt("iRef"); }
		public set(int ref) { this.SetInt("iRef", ref); }
	}

	property float fLastHitTime {
		public get() { return this.GetFloat("fLastHitTime"); }
		public set(float lasthittime) { this.SetFloat("fLastHitTime", lasthittime); }
	}

	property bool bActive {
		public get() { return this.GetBool("bActive"); }
		public set(bool active) { this.SetBool("bActive", active); }
	}
}
