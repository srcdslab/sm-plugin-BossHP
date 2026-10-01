#if defined _class_centity_
#endinput
#endif
#define _class_centity_

methodmap CEntity < Basic
{
	public CEntity()
	{
		Basic myclass = new Basic();

		myclass.SetInt("iIndex", 0);
		myclass.SetString("sName", "");
		myclass.SetInt("iHealth", 0);
		myclass.SetInt("iMaxHealth", 0);
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

	property int iIndex {
		public get() { return this.GetInt("iIndex"); }
		public set(int index) { this.SetInt("iIndex", index); }
	}

	property int iHealth {
		public get() { return this.GetInt("iHealth"); }
		public set(int health) { this.SetInt("iHealth", health); }
	}

	property int iMaxHealth {
		public get() { return this.GetInt("iMaxHealth"); }
		public set(int maxhealth) { this.SetInt("iMaxHealth", maxhealth); }
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
