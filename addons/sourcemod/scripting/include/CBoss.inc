#if defined _class_cboss_
  #endinput
#endif
#define _class_cboss_

methodmap CBoss < Basic
{
	public CBoss()
	{
		Basic myclass = new Basic();

		myclass.SetHandle("dConfig", INVALID_HANDLE);
		myclass.SetBool("bActive", false);
		myclass.SetBool("bShow", true);
		myclass.SetInt("iTemplateNum", -1);
		myclass.SetInt("iHealth", 0);
		myclass.SetInt("iLastHealth", 0);
		myclass.SetFloat("fLastChange", 0.0);
		myclass.SetFloat("fWaitUntil", 0.0);
		myclass.SetFloat("fShowAt", 0.0);
		myclass.SetFloat("fKillAt", 0.0);
		myclass.SetInt("iEntity", INVALID_ENT_REFERENCE);

		return view_as<CBoss>(myclass);
	}

	property CConfig dConfig
	{
		public get()
		{
			return view_as<CConfig>(this.GetHandle("dConfig"));
		}
		public set(CConfig value)
		{
			this.SetHandle("dConfig", value);
		}
	}

	property bool bActive
	{
		public get()
		{
			return this.GetBool("bActive");
		}
		public set(bool value)
		{
			this.SetBool("bActive", value);
		}
	}

	property bool bShow
	{
		public get()
		{
			return this.GetBool("bShow");
		}
		public set(bool value)
		{
			this.SetBool("bShow", value);
		}
	}

	property int iTemplateNum
	{
		public get()
		{
			return this.GetInt("iTemplateNum");
		}
		public set(int value)
		{
			this.SetInt("iTemplateNum", value);
		}
	}

	property int iHealth
	{
		public get()
		{
			return this.GetInt("iHealth");
		}
		public set(int value)
		{
			this.SetInt("iHealth", value);
		}
	}

	property int iLastHealth
	{
		public get()
		{
			return this.GetInt("iLastHealth");
		}
		public set(int value)
		{
			this.SetInt("iLastHealth", value);
		}
	}

	property float fLastChange
	{
		public get()
		{
			return this.GetFloat("fLastChange");
		}
		public set(float value)
		{
			this.SetFloat("fLastChange", value);
		}
	}

	property float fWaitUntil
	{
		public get()
		{
			return this.GetFloat("fWaitUntil");
		}
		public set(float value)
		{
			this.SetFloat("fWaitUntil", value);
		}
	}

	property float fShowAt
	{
		public get()
		{
			return this.GetFloat("fShowAt");
		}
		public set(float value)
		{
			this.SetFloat("fShowAt", value);
		}
	}

	property float fKillAt
	{
		public get()
		{
			return this.GetFloat("fKillAt");
		}
		public set(float value)
		{
			this.SetFloat("fKillAt", value);
		}
	}

	property int iEntity
	{
		public get()
		{
			return this.GetInt("iEntity");
		}
		public set(int value)
		{
			this.SetInt("iEntity", value);
		}
	}

	property bool IsBreakable {
		public get() {
			return this.dConfig.IsBreakable;
		}
	}

	property bool IsCounter {
		public get() {
			return this.dConfig.IsCounter;
		}
	}

	property bool IsHPBar {
		public get() {
			return this.dConfig.IsHPBar;
		}
	}
}

methodmap CBossBreakable < CBoss
{
	public CBossBreakable()
	{
		CBoss myclass = new CBoss();

		myclass.SetInt("iBreakableEnt", INVALID_ENT_REFERENCE);

		return view_as<CBossBreakable>(myclass);
	}

	property int iBreakableEnt
	{
		public get()
		{
			return this.GetInt("iBreakableEnt");
		}
		public set(int value)
		{
			this.SetInt("iBreakableEnt", value);
		}
	}

	property CConfigBreakable Config
	{
		public get()
		{
			return view_as<CConfigBreakable>(this.dConfig);
		}
		public set(CConfigBreakable value)
		{
			this.dConfig = value;
		}
	}
}

methodmap CBossCounter < CBoss
{
	public CBossCounter()
	{
		CBoss myclass = new CBoss();

		myclass.SetInt("iCounterEnt", INVALID_ENT_REFERENCE);

		return view_as<CBossCounter>(myclass);
	}

	property int iCounterEnt
	{
		public get()
		{
			return this.GetInt("iCounterEnt");
		}
		public set(int value)
		{
			this.SetInt("iCounterEnt", value);
		}
	}

	property CConfigCounter Config
	{
		public get()
		{
			return view_as<CConfigCounter>(this.dConfig);
		}
		public set(CConfigCounter value)
		{
			this.dConfig = value;
		}
	}
}

methodmap CBossHPBar < CBossCounter
{
	public CBossHPBar()
	{
		CBoss myclass = new CBossCounter();

		myclass.SetInt("iIteratorEnt", INVALID_ENT_REFERENCE);
		myclass.SetInt("iBackupEnt", INVALID_ENT_REFERENCE);

		return view_as<CBossHPBar>(myclass);
	}

	property int iIteratorEnt
	{
		public get()
		{
			return this.GetInt("iIteratorEnt");
		}
		public set(int value)
		{
			this.SetInt("iIteratorEnt", value);
		}
	}

	property int iBackupEnt
	{
		public get()
		{
			return this.GetInt("iBackupEnt");
		}
		public set(int value)
		{
			this.SetInt("iBackupEnt", value);
		}
	}

	property CConfigHPBar Config
	{
		public get()
		{
			return view_as<CConfigHPBar>(this.dConfig);
		}
		public set(CConfigHPBar value)
		{
			this.dConfig = value;
		}
	}
}
