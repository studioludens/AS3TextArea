package com.riaspace.as3TextArea
{
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.text.StyleSheet;
	import flash.utils.Timer;
	
	import flashx.textLayout.conversion.ITextImporter;
	import flashx.textLayout.conversion.TextConverter;
	import flashx.textLayout.elements.Configuration;
	import flashx.textLayout.formats.LineBreak;
	import flashx.textLayout.formats.TextLayoutFormat;
	import flashx.textLayout.formats.WhiteSpaceCollapse;
	
	import spark.components.TextArea;
	import spark.components.TextSelectionHighlighting;
	import spark.events.TextOperationEvent;
	
	[Bindable]
	public class AS3TextArea extends TextArea
	{
		private static const TEXT_LAYOUT_NAMESPACE:String = "http://ns.adobe.com/textLayout/2008";
		
		public var accessModifiers:Array = ["public", "private", "protected", "internal"];
		
		public var classMethodVariableModifiers:Array = ["class", "const", "extends", "final", "function", "get", "dynamic", "implements", "interface", "native", "new", "set", "static"]; 
		
		public var flowControl:Array = ["break", "case", "continue", "default", "do", "else", "for", "for\ each", "if", "is", "label", "typeof", "return", "switch", "while", "in"];
		
		public var errorHandling:Array = ["catch", "finally", "throw", "try"];
		
		public var packageControl:Array = ["import", "package"];
		
		public var variableKeywords:Array = ["super", "this", "var"];
		
		public var returnTypeKeyword:Array = ["void"];
		
		public var namespaces:Array = ["default xml namespace", "namespace", "use namespace"];
		
		public var literals:Array = ["null", "true", "false"];
		
		public var primitives:Array = ["Boolean", "int", "Number", "String", "uint"];
		
		public var strings:Array = ['".*?"', "'.*?'"];
		
		public var comments:Array = ["//.*$", "/\\\*[.\\w\\s]*\\\*/", "/\\\*([^*]|[\\r\\n]|(\\\*+([^*/]|[\\r\\n])))*\\\*/"];
		
		public var defaultStyleSheet:String = ".text{color:#000000;font-family: courier;} .default{color:#0839ff;} .var{color:#80aad4;} .function{color:#55a97f;}.strings{color:#a82929;} .comment{color:#0e9e0f;font-style:italic;} .asDocComment{color:#5d78c9;}";
		
		protected var _syntaxStyleSheet:String;
		
		protected var syntax:RegExp;
		
		protected var styleSheet:StyleSheet = new StyleSheet();
		
		protected var importer:ITextImporter;
		
		protected var pseudoThread:Timer = new Timer(300, 1);
		
		public function AS3TextArea()
		{
			super();
			
			initTextFlowImporter();
			
			initSyntaxRegExp();
			styleSheet.parseCSS(defaultStyleSheet);
			
			selectable = true;
			selectionHighlighting = TextSelectionHighlighting.ALWAYS;
			setStyle("lineBreak", LineBreak.EXPLICIT);
			
			addEventListener("textChanged", 
				function(event:Event):void 
				{
					colorize();
				});
			
			addEventListener(TextOperationEvent.CHANGE, 
				function(event:TextOperationEvent):void
				{
					if (!pseudoThread.running)
						pseudoThread.start();
				});
			
			pseudoThread.addEventListener(TimerEvent.TIMER, 
				function(event:TimerEvent):void
				{
					colorize();
					pseudoThread.reset();
				});
		}
		
		protected function initTextFlowImporter():void 
		{
			var config:Configuration = new Configuration();
			config.manageTabKey = true;
			
			var format:TextLayoutFormat = new TextLayoutFormat(config.textFlowInitialFormat);
			format.whiteSpaceCollapse = WhiteSpaceCollapse.PRESERVE;
			config.textFlowInitialFormat = format;
			
			importer = TextConverter.getImporter(TextConverter.TEXT_LAYOUT_FORMAT, config);
			importer.throwOnError = true;
		}
		
		protected function initSyntaxRegExp():void 
		{
			var pattern:String = "";
			
			for each(var str:String in strings.concat(comments))
			{
				pattern += str + "|";
			}
			
			var createRegExp:Function = function(keywords:Array):String
			{
				var result:String = "";
				for each(var keyword:String in keywords)
				{
					result += (result != "" ? "|" : "") + "\\b" + keyword + "\\b";
				}
				return result;
			};
			
			pattern += createRegExp(accessModifiers)
				+ "|" 
				+ createRegExp(classMethodVariableModifiers)
				+ "|"
				+ createRegExp(flowControl)
				+ "|"
				+ createRegExp(errorHandling)
				+ "|"
				+ createRegExp(packageControl)
				+ "|"
				+ createRegExp(variableKeywords)
				+ "|"
				+ createRegExp(returnTypeKeyword)
				+ "|"
				+ createRegExp(namespaces)
				+ "|"
				+ createRegExp(literals)
				+ "|"
				+ createRegExp(primitives);
			
			this.syntax = new RegExp(pattern, "gm");
		}
		
		protected function colorize(event:Event = null):void
		{
			var actPos:int = this.selectionActivePosition;
			var ancPos:int = this.selectionAnchorPosition;
			
			var script:String = this.text
				.replace(/&/g, "&amp;")
				.replace(/</g, "&lt;")
				.replace(/>/g, "&gt;");
			
			var token:* = syntax.exec(script);
			while(token)
			{
				var tokenValue:String = token[0];
				var tokenType:String = getTokenType(tokenValue);
				
				var tokenStyleName:String = "." + tokenType;
				var tokenStyle:Object = 
					styleSheet.styleNames.indexOf(tokenStyleName) > -1
					?
					styleSheet.getStyle("." + tokenType)
					:
					styleSheet.getStyle(".default");
				
				var spanTemplate:String = "<span" + getStyleAttributes(tokenStyle) + "></span>";
				
				script = 
					script.substring(0, syntax.lastIndex - tokenValue.length) 
					+ spanTemplate.replace(/></, ">" + tokenValue + "<")
					+ script.substring(syntax.lastIndex);
				
				syntax.lastIndex = syntax.lastIndex + spanTemplate.length; 
				token = syntax.exec(script);
			}
			
			var p:String = "<TextFlow xmlns=\"" + TEXT_LAYOUT_NAMESPACE + "\"><p " 
				+ getStyleAttributes(styleSheet.getStyle(".text")) + ">" + script + "</p></TextFlow>";
			
			this.textFlow = importer.importToFlow(p);
			
			this.scrollToRange(ancPos, actPos);
			this.selectRange(ancPos, actPos);
		}
		
		protected function getStyleAttributes(style:Object):String
		{
			return (style.color ? " color='" + style.color + "'" : "")
			+ (style.fontFamily ? " fontFamily='" + style.fontFamily + "'" : "")
				+ (style.fontSize ? " fontSize='" + style.fontSize + "'" : "")
				+ (style.fontStyle ? " fontStyle='" + style.fontStyle + "'" : "")
				+ (style.fontWeight ? " fontWeight='" + style.fontWeight + "'" : ""); 
		}
		
		protected function getTokenType(tokenValue:String):String
		{
			var result:String;
			if (tokenValue == "var")
			{
				return "var";
			}
			else if (tokenValue == "function")
			{
				return "function";
			}
			else if (tokenValue.indexOf("\"") == 0 || tokenValue.indexOf("'") == 0)
			{
				return "strings";
			}
			else if (tokenValue.indexOf("/**") == 0)
			{
				return "asDocComment";
			}
			else if (tokenValue.indexOf("//") == 0 || tokenValue.indexOf("/*") == 0)
			{
				return "comment";
			}
			else if (accessModifiers.indexOf(tokenValue) > -1)
			{
				return "accessModifiers";
			}
			else if (classMethodVariableModifiers.indexOf(tokenValue) > -1)
			{
				return "classMethodVariableModifiers";
			}
			else if (flowControl.indexOf(tokenValue) > -1)
			{
				return "flowControl";
			}
			else if (errorHandling.indexOf(tokenValue) > -1)
			{
				return "errorHandling";
			}
			else if (packageControl.indexOf(tokenValue) > -1)
			{
				return "packageControl";
			}
			else if (variableKeywords.indexOf(tokenValue) > -1)
			{
				return "variableKeywords";
			}
			else if (returnTypeKeyword.indexOf(tokenValue) > -1)
			{
				return "returnTypeKeyword";
			}
			else if (namespaces.indexOf(tokenValue) > -1)
			{
				return "namespaces";
			}
			else if (literals.indexOf(tokenValue) > -1)
			{
				return "literals";
			}
			else if (primitives.indexOf(tokenValue) > -1)
			{
				return "primitives";
			}
			return result;
		}
		
		public function get syntaxStyleSheet():String
		{
			return _syntaxStyleSheet;
		}
		
		public function set syntaxStyleSheet(value:String):void
		{
			_syntaxStyleSheet = value;
			
			styleSheet.clear();
			if (_syntaxStyleSheet)
				styleSheet.parseCSS(_syntaxStyleSheet);
			else
				styleSheet.parseCSS(defaultStyleSheet);
			
			colorize();
		}
	}
}