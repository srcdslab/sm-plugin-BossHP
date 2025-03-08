#if defined _class_cconfig_
  #endinput
#endif
#define _class_cconfig_

#include <basic>

enum eConfigMethod
{
	eConfigMethod_Invalid = 0,
	eConfigMethod_Breakable = 1,
	eConfigMethod_Counter = 2,
	eConfigMethod_HPBar = 3
}

methodmap CConfig < Basic
{
	public CConfig()
	{
		Basic myclass = new Basic();

		myclass.SetString("sName", "");
		myclass.SetInt("iMethod", eConfigMethod_Invalid);
		myclass.SetString("sTrigger", "");
		myclass.SetString("sOutput", "");
		myclass.SetFloat("fTriggerDelay", 0.0);
		myclass.SetString("sShowTrigger", "");
		myclass.SetString("sShowOutput", "");
		myclass.SetFloat("fShowTriggerDelay", 0.0);
		myclass.SetString("sKillTrigger", "");
		myclass.SetString("sKillOutput", "");
		myclass.SetFloat("fKillTriggerDelay", 0.0);
		myclass.SetBool("bMultiTrigger", false);
		myclass.SetBool("bNameFixup", false);
		myclass.SetBool("bIgnore", false);
		myclass.SetBool("bShowBeaten", false);
		myclass.SetFloat("fTimeout", -1.0);
		myclass.SetInt("iOffset", 0);

		return view_as<CConfig>(myclass);
	}

	public bool GetName(char[] buffer, int length)
	{
		return this.GetString("sName", buffer, length);
	}

	public void SetName(const char[] buffer)
	{
		this.SetString("sName", buffer);
	}

	property eConfigMethod iMethod
	{
		public get()
		{
			return view_as<eConfigMethod>(this.GetInt("iMethod"));
		}
		public set(eConfigMethod value)
		{
			this.SetInt("iMethod", view_as<int>(value));
		}
	}

	public bool GetTrigger(char[] buffer, int length)
	{
		return this.GetString("sTrigger", buffer, length);
	}

	public void SetTrigger(const char[] buffer)
	{
		this.SetString("sTrigger", buffer);
	}

	public bool GetOutput(char[] buffer, int length)
	{
		return this.GetString("sOutput", buffer, length);
	}

	public void SetOutput(const char[] buffer)
	{
		this.SetString("sOutput", buffer);
	}

	property float fTriggerDelay
	{
		public get()
		{
			return this.GetFloat("fTriggerDelay");
		}
		public set(float value)
		{
			this.SetFloat("fTriggerDelay", value);
		}
	}

	public bool GetShowTrigger(char[] buffer, int length)
	{
		return this.GetString("sShowTrigger", buffer, length);
	}

	public void SetShowTrigger(const char[] buffer)
	{
		this.SetString("sShowTrigger", buffer);
	}

	public bool GetShowOutput(char[] buffer, int length)
	{
		return this.GetString("sShowOutput", buffer, length);
	}

	public void SetShowOutput(const char[] buffer)
	{
		this.SetString("sShowOutput", buffer);
	}

	property float fShowTriggerDelay
	{
		public get()
		{
			return this.GetFloat("fShowTriggerDelay");
		}
		public set(float value)
		{
			this.SetFloat("fShowTriggerDelay", value);
		}
	}

	public bool GetKillTrigger(char[] buffer, int length)
	{
		return this.GetString("sKillTrigger", buffer, length);
	}

	public void SetKillTrigger(const char[] buffer)
	{
		this.SetString("sKillTrigger", buffer);
	}

	public bool GetKillOutput(char[] buffer, int length)
	{
		return this.GetString("sKillOutput", buffer, length);
	}

	public void SetKillOutput(const char[] buffer)
	{
		this.SetString("sKillOutput", buffer);
	}

	property float fKillTriggerDelay
	{
		public get()
		{
			return this.GetFloat("fKillTriggerDelay");
		}
		public set(float value)
		{
			this.SetFloat("fKillTriggerDelay", value);
		}
	}

	property bool bMultiTrigger
	{
		public get()
		{
			return this.GetBool("bMultiTrigger");
		}
		public set(bool value)
		{
			this.SetBool("bMultiTrigger", value);
		}
	}

	property bool bNameFixup
	{
		public get()
		{
			return this.GetBool("bNameFixup");
		}
		public set(bool value)
		{
			this.SetBool("bNameFixup", value);
		}
	}

	property bool bIgnore
	{
		public get()
		{
			return this.GetBool("bIgnore");
		}
		public set(bool value)
		{
			this.SetBool("bIgnore", value);
		}
	}

	property bool bShowBeaten
	{
		public get()
		{
			return this.GetBool("bShowBeaten");
		}
		public set(bool value)
		{
			this.SetBool("bShowBeaten", value);
		}
	}

	property float fTimeout
	{
		public get()
		{
			return this.GetFloat("fTimeout");
		}
		public set(float value)
		{
			this.SetFloat("fTimeout", value);
		}
	}

	property int iOffset
	{
		public get()
		{
			return this.GetInt("iOffset");
		}
		public set(int value)
		{
			this.SetInt("iOffset", value);
		}
	}

	property bool IsBreakable {
		public get() {
			return (this.iMethod == eConfigMethod_Breakable);
		}
	}

	property bool IsCounter {
		public get() {
			return (this.iMethod == eConfigMethod_Counter);
		}
	}

	property bool IsHPBar {
		public get() {
			return (this.iMethod == eConfigMethod_HPBar);
		}
	}
}

methodmap CConfigBreakable < CConfig
{
	public CConfigBreakable()
	{
		CConfig myclass = new CConfig();

		myclass.SetString("sBreakable", "");

		myclass.iMethod = eConfigMethod_Breakable;

		return view_as<CConfigBreakable>(myclass);
	}

	public bool GetBreakable(char[] buffer, int length)
	{
		return this.GetString("sBreakable", buffer, length);
	}

	public void SetBreakable(const char[] buffer)
	{
		this.SetString("sBreakable", buffer);
	}
}

methodmap CConfigCounter < CConfig
{
	public CConfigCounter()
	{
		CConfig myclass = new CConfig();

		myclass.SetString("sCounter", "");
		myclass.SetBool("bCounterReverse", false);
		myclass.SetInt("iMode", -1);

		myclass.iMethod = eConfigMethod_Counter;

		return view_as<CConfigCounter>(myclass);
	}

	public bool GetCounter(char[] buffer, int length)
	{
		return this.GetString("sCounter", buffer, length);
	}

	public void SetCounter(const char[] buffer)
	{
		this.SetString("sCounter", buffer);
	}

	property int iMode
	{
		public get()
		{
			return this.GetInt("iMode");
		}
		public set(int value)
		{
			this.SetInt("iMode", value);
		}
	}

	property bool bCounterReverse
	{
		public get()
		{
			return this.GetBool("bCounterReverse");
		}
		public set(bool value)
		{
			this.SetBool("bCounterReverse", value);
		}
	}
}

methodmap CConfigHPBar < CConfigCounter
{
	public CConfigHPBar()
	{
		CConfigCounter myclass = new CConfigCounter();

		myclass.SetString("sIterator", "");
		myclass.SetString("sBackup", "");
		myclass.SetBool("bIteratorReverse", false);
		myclass.SetInt("iBarMode", -1);

		myclass.iMethod = eConfigMethod_HPBar;

		return view_as<CConfigHPBar>(myclass);
	}

	public bool GetIterator(char[] buffer, int length)
	{
		return this.GetString("sIterator", buffer, length);
	}

	public void SetIterator(const char[] buffer)
	{
		this.SetString("sIterator", buffer);
	}

	public bool GetBackup(char[] buffer, int length)
	{
		return this.GetString("sBackup", buffer, length);
	}

	public void SetBackup(const char[] buffer)
	{
		this.SetString("sBackup", buffer);
	}

	property int iBarMode
	{
		public get()
		{
			return this.GetInt("iBarMode");
		}
		public set(int value)
		{
			this.SetInt("iBarMode", value);
		}
	}

	property bool bIteratorReverse
	{
		public get()
		{
			return this.GetBool("bIteratorReverse");
		}
		public set(bool value)
		{
			this.SetBool("bIteratorReverse", value);
		}
	}
}
