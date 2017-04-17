%option noyywrap nodefault yylineno
%x MAIN
%x IGNORE
%{
  /*下一步就是要处理函数的额问题，把有实现的函数匹配出来并且保留，匹配函数的正则表达式(\w+)\s+[\*,&]*\s*(\w+)\s*\(*/


  extern int yylineno;
  int nesting;/*这个变量记录了进入嵌套的次数*/
  /*为了方便使用，打算把这个改为结构体*/
  /*这里放置一个结构体，这个结构体里面存着一个关键函数（包括if、）的*/


  char* neststack[20];/*最多支持20层嵌套，每一个函数体都有一个名字，比如在第一个if函数体就是if#1，第二个就是if#2，当然这还没有完
  不仅要加上函数体，还要加上这个if所出现的行号比如第一个出现在第1000行的if就是 if#1#1000 ，然后就还有嵌套问题，如果第一个if里面还有
  一个if，那就if#1#1000$if#2#1005这样子就是第二个存在文本中的if，当然这个是存在文本中的两行的*/
  /*我们在查找关键变量的时候需要一个C语言的模板文件，因为有局部变量和全局变量的问题，我们需要把关键函数的调用行，关键参数的出现行，if和while出现的行，代码块出现的行
  全部保留下来*/
  FILE* structureFile;/*这个文件存的是main函数的结构主要负责分支和循环的结构其实这里面还有对应的，当然后续会加上关键函数，关键函数也会被嵌入这个里面
  这个文件中放的内容基本可以认为就是上面那个数组里面存的内容，这个文件是用来帮助生成DAG图的*/
%}

%%
"main(" {
  printf("%s",yytext);
  //printf("检测到main函数在第%d行\n" , yylineno);
  {
    char c;
    while((c = input()) && c != '{')
    {
        printf("%s" , &c);
    }
    printf("%s" , &c);
  }
  printf("现在进入函数体，下面打印函数体内容：\n");
  BEGIN MAIN;
}

<MAIN>[^A-Za-z0-9]{1}"if (" {
  //因为连带了if前面东西的匹配,所以如果前面是"{"或者"}"的话要另做应对
  if(yytext[0] == '{'){
    nesting++;
  }
  if(yytext[0] == '}'){
    nesting--;
  }

  /*这个函数块主要负责if语句*/
  printf("%s", yytext);
  printf("检测到分支在第%d行,nesting=%d\n" , yylineno,nesting);


  //这个是和普通函数一样的关键代码，需要生成DAG图的，我们需要在neststack数组中记录下他们出现的
  //这里进行字符串的拼接
  char temp[100];//这个是最后要写到栈里面的东西，这里必须要声明一个大小，要不就会和numString的内存分配产生冲突
  //这步将整形转化为字符串
  //sprintf(temp , "if#%d#%d" , nesting , yylineno);
  //printf("%s\n",temp);
}


<MAIN>[^A-Za-z0-9]{1}"else {" {
  /*这个匹配else的情况还待测试*/
  /*这个代码块处理if对应的else的情况*/
  //因为连带了else前面东西的匹配,所以如果前面是"{"或者"}"的话要另做应对
  if(yytext[0] == '{'){
    nesting++;
  }
  if(yytext[0] == '}'){
    nesting--;
  }

  printf("%s", yytext);
  printf("检测到分支的另一支在第%d行,nesting=%d\n" , yylineno,nesting);
}

<MAIN>[^A-Za-z0-9]{1}"while ("  {
  //因为连带了while前面东西的匹配,所以如果前面是"{"或者"}"的话要另做应对
  if(yytext[0] == '{'){
    nesting++;
  }
  if(yytext[0] == '}'){
    nesting--;
  }

  /*这个函数块主要负责while语句*/
  printf("%s", yytext);
  printf("检测到循环开始在第%d行,nesting=%d\n" , yylineno,nesting);
}

<MAIN>\{  {
  printf("%s", yytext);
  /*这说明代码进入了一个单独的函数块*/
  nesting++;
}

<MAIN>\} {
    printf("检测到代码块结束在第%d行,nesting=%d\n" , yylineno,nesting);
    printf("%s", yytext);
    //在main函数之后会进入忽略态，忽略掉后面所有东西
    if(nesting == 0){
      BEGIN IGNORE;
    }

    nesting--;
}

<MAIN>.|\n {
  printf("%s", yytext);
}

<IGNORE>. {
  //忽略
}

<IGNORE>\n  {
  //忽略
}

. {printf("%s", yytext);}
\n {printf("%s", yytext);}

%%
int main(int argc, char *argv[]){
  yylineno = 1;
  nesting = 0;
  /*首先把输入和输出文件规定好*/
  if(argc > 1){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");

  yylex();
}
