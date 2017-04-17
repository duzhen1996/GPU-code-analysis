%option noyywrap nodefault yylineno
%x MARKS
%s MAIN
%s IF
%s ELSE
%s DO
%s FOR


%{
  //这里我们使用一些枚举来定义状态。
  enum STATE  {
    STATENONE = 0,
    STATEMAIN = 1,
    STATEIF = 2,
    STATEDO = 3,
    STATEWHILE = 4,
    STATEELSE = 5,
    STATEFOR = 6,
  };



  //在这个文件中我们将要以上一次扫描的输出为输入，勾选所有有关的行，这个文件要由java程序生成
  //我们需要几个数组首先就是我么需要的变量名的数组，这些变量一开始就是关键变量，然后我们在整个文件中
  //找到这些变量，记录这些变量所在行，第一次扫描结束
  //然后我们就进入第二次扫描，我们扫描这些关建行，并且看看这些关建行有没有新的间接相关变量
  //第二次扫描我们得到其他的一些关键变量的名称
  //然后我们进行第三次扫描，第三次扫描的原理和第一次是一样的，通过变量得出行号
  //所以说我们实际上是在进行两种类型扫描的交替过程
  //由变量得行号---->由行号得变量名------->由变量得行号
  //我们一直扫描，直到我们的我们的行号不再增加
  extern int yylineno;

  //我们使用一个命名模式来存储一个变量的变量名,除此之外我们不匹配引号中的东西，我们引入一个新的状态去处理引号内的情况
  //因为我们需要保持这个程序的结构，所以当我们发现我们要查找的变量在一个if、while、else、do，或者只是一个单纯的函数块中的时候我们就要保持这个函数块
  //所以当我们匹配if、else、while、do的时候都要慎重考虑，我们要进入单独的状态，如果发现了在这些东西里面有我们想要的关键变量，那么就要有所保留



  //这个变量用来判断是不是出现了单引号，在单引号之后这个变量的值变成1,再次出现单引号的时候这个值变为0
  int singleMark;


  //因为关键变量在做完内存申请等操作之后可能会去处理很多我们不关心的操作，所以我们需要一组数组来标明哪些我们最后关心这个变量的值是在什么地方
  //这个变量由java程序给出
  char* keyName[] = {"WORK_SIZE"};
  int keyVarLineCount[] = {70};
  //这个数组存着上面两个数组的大小，51存的是最后一次所需要这个变量的行号。
  int size = 1;



  //我们需要一个nesting变量来记录大括号的优先等级
  int nesting;
  //我们需要使用smallnesting来
  int smallnesting;
  //我们还需要一个变量来判断if while等小括号里面的内容是不是形参
  int ifParam;


  //我们加入一种特殊的栈结构，来解决if、while、for、do while、if else相互嵌套的问题。
  //这个栈结构的每一行是一个结构体，这个结构体主要是四个部分组成，"状态名","整个状态包含的行号"（这是一个数组）,"当前的嵌套等级"
  //第四部分就是状态包含的行号的数组已经占用的空间。实际上就是一个一个指向数组下一个空位的指针。
  //头部指针实际上只会是一个范围，用两位的int数组就可以搞定了。
  struct stateNode{
    enum STATE nowstate;
    int headLine[2];
    int nownesting;
    int nowindex;
    int remainHead;
  };

  struct stateNode stateStack[100]={};
  int stateStackTop;


  void addTopLine(struct stateNode* node, int lineCount);
  void printStack(struct stateNode* stateStack , int stateStackTop);
  enum STATE exitState(struct stateNode* stateStack , int *stateStackTop);
  //这个函数将当前栈中的所有节点的remainHead项变为1
  void remainLine();

  int ifMain;
%}

KEYVARNAME ("WORK_SIZE")

%%
[^A-Za-z0-9]{1}"main"(" "|\t|\n)*"("  {
  //这里就是匹配到了main函数，我们需要在main函数中进行勾选
  printf("匹配到了main函数在第%d行\n",yylineno);
  //对于main函数我们也进行压栈好了
  smallnesting++;
  stateStackTop++;
  struct stateNode newstateNode = {STATEMAIN,{yylineno},nesting,0,0};
  stateStack[stateStackTop] = newstateNode;
  //这里压栈完毕
  //在main函数也要讨论头部形参的问题
  ifParam = 1;
  addTopLine(&stateStack[stateStackTop],yylineno);
  printStack(stateStack , stateStackTop);
  ifMain = 1;
  BEGIN MAIN;
}

<ELSE>"{" {
  nesting++;
}

<ELSE>"}" {
  nesting--;
  //是否退出else状态的标准是看看栈顶的状态所在的nesting是不是和当前的nesting一样
  if(stateStack[stateStackTop].nownesting == nesting){
    //这个时候退出当前状态
    //我们推栈，然后查看新的栈顶
    //然后返回回来
    //else要跟最近的IF一起推栈
    enum STATE nextState = exitState(stateStack , &stateStackTop);

    nextState = exitState(stateStack , &stateStackTop);
    printStack(stateStack,stateStackTop);
    if(nextState == STATENONE){
      printf("%s\n","回到初始状态");
      BEGIN INITIAL;
    }else
    if(nextState == STATEIF){
      printf("%s\n","回到IF状态");
      BEGIN IF;
    }else
    if(nextState == STATEELSE){
      printf("%s\n","回到ELSE状态");
      BEGIN ELSE;
    }else
    if(nextState == STATEWHILE){
      printf("%s\n","回到WHILE状态");
      BEGIN IF;
    }else
    if(nextState == STATEFOR){
      printf("%s\n","回到FOR状态");
      BEGIN IF;
    }else
    if(nextState == STATEDO){
      printf("%s\n","回到DO状态");
      BEGIN DO;
    }else
    if(nextState == STATEMAIN){
      printf("%s\n","回到MAIN状态");
      BEGIN MAIN;
    }
  }
}



<IF>"(" {
  //我们需要这个东西来定位if的形参
  if(smallnesting == 0 && ifParam == 1){
    //这里说明这个括号里面的内容都是if的形参，要加入函数头
    //这里就要使用addTopLine函数
    addTopLine(&stateStack[stateStackTop],yylineno);
    printStack(stateStack,stateStackTop);
  }
  smallnesting++;
}

<IF>")" {
  smallnesting--;
  if(smallnesting == 0 && ifParam == 1){
    //这里说明if的形参搞定了
    addTopLine(&stateStack[stateStackTop],yylineno);
    printStack(stateStack,stateStackTop);
    ifParam = 0;
    //到这里形参的所有所在行就搜罗完毕了
  }
}

<IF>")"(" "|\t|\n)*";" {
  //这里是匹配while形参之后直接就是分号的情况
  smallnesting--;
  if(smallnesting == 0 && ifParam == 1){
    //这里说明应该就是Do后面的While。我们要做的就是连续弹两次栈
    addTopLine(&stateStack[stateStackTop],yylineno);
    printStack(stateStack,stateStackTop);
    ifParam = 0;
    //到这里形参的所有所在行就搜罗完毕了

    //我们在这里需要看看下面的那个DO是不是也要去除
    //这里的while除了要保证自己形参内部的变量之外，还要看看和他搭配的DO，如果DO是要保留的，那么这个WHILE也要保留
    if(stateStack[stateStackTop-1].nowstate==STATEDO && stateStack[stateStackTop-1].remainHead == 1){
      stateStack[stateStackTop].remainHead = 1;
    }

    //我们在这里连续弹两次栈
    enum STATE nextState = exitState(stateStack , &stateStackTop);

    nextState = exitState(stateStack , &stateStackTop);
    printStack(stateStack,stateStackTop);
    if(nextState == STATENONE){
      printf("%s\n","回到初始状态");
      BEGIN INITIAL;
    }else
    if(nextState == STATEIF){
      printf("%s\n","回到IF状态");
      BEGIN IF;
    }else
    if(nextState == STATEELSE){
      printf("%s\n","回到ELSE状态");
      BEGIN ELSE;
    }else
    if(nextState == STATEWHILE){
      printf("%s\n","回到WHILE状态");
      BEGIN IF;
    }else
    if(nextState == STATEFOR){
      printf("%s\n","回到FOR状态");
      BEGIN IF;
    }else
    if(nextState == STATEDO){
      printf("%s\n","回到DO状态");
      BEGIN DO;
    }else
    if(nextState == STATEMAIN){
      printf("%s\n","回到MAIN状态");
      BEGIN MAIN;
    }
  }
}

<IF>"}"(" "|\t|\n)*"else"(" "|\t|\n)*"{"  {
  //这里我们需要看看是不是在一般情况下只有在我们if结束的时候才有可能匹配到这个，因为有
  //状态栈的缘故。所以我们一般情况下不会看到else在栈中和他下面的那个if在不同的优先级。
  printf("%s\n","匹配到else");
  nesting--;
  //这个时候我们需要进入else状态，然后把栈搞好
  stateStackTop++;
  struct stateNode newstateNode = {STATEELSE,{yylineno},nesting,0,0};

  stateStack[stateStackTop] = newstateNode;



  //这里压栈完毕
  addTopLine(&stateStack[stateStackTop],yylineno);
  printStack(stateStack,stateStackTop);
  nesting++;
  BEGIN ELSE;
}

<IF>"}" {
  nesting--;
  printf("%s%d  %d，在第%d行\n","匹配到右大括号nesting = ", nesting , stateStack[stateStackTop].nownesting ,yylineno);
  //判断这里是不是应该退出IF模式
  if(nesting == stateStack[stateStackTop].nownesting){
    printf("%s%d\n","当前nesting=",nesting);
    //这里应该退出IF模式，因为这里已经搞定了
    enum STATE nextState = exitState(stateStack , &stateStackTop);
    printStack(stateStack,stateStackTop);
    if(nextState == STATENONE){
      printf("%s\n","回到初始状态");
      BEGIN INITIAL;
    }else
    if(nextState == STATEIF){
      printf("%s\n","回到IF状态");
      BEGIN IF;
    }else
    if(nextState == STATEELSE){
      printf("%s\n","回到ELSE状态");
      BEGIN ELSE;
    }else
    if(nextState == STATEWHILE){
      printf("%s\n","回到WHILE状态");
      BEGIN IF;
    }else
    if(nextState == STATEFOR){
      printf("%s\n","回到FOR状态");
      BEGIN IF;
    }else
    if(nextState == STATEDO){
      printf("%s\n","回到DO状态");
      BEGIN DO;
    }else
    if(nextState == STATEMAIN){
      printf("%s\n","回到MAIN状态");
      BEGIN MAIN;
    }
  }
}


<IF>"{" {
  nesting++;
}



<DO>"{" {
  nesting++;
}

<DO>"}" {
  //判定DO弹栈的标准不是右大括号的嵌套等级，而是后面带分号的WHILE。
  printf("在do中匹配到了右大括号\n");
  nesting--;
}

<MAIN>"{" {

  nesting++;
}

<MAIN>"}" {
  nesting--;
  if(nesting == 0){
    //这个时候推出MAIN状态就好了
    ifMain = 0;
    printf("退出main\n");
    exitState(stateStack , &stateStackTop);
    BEGIN INITIAL;
  }
}

<MAIN>"(" {
  //我们需要这个东西来定位if的形参
  if(smallnesting == 0 && ifParam == 1){
    //这里说明这个括号里面的内容都是main的形参，要加入函数头
    //这里就要使用addTopLine函数
    addTopLine(&stateStack[stateStackTop],yylineno);
    printStack(stateStack,stateStackTop);
  }
  smallnesting++;
}

<MAIN>")" {
  smallnesting--;
  if(smallnesting == 0 && ifParam == 1){
    //这里说明main的形参搞定了
    addTopLine(&stateStack[stateStackTop],yylineno);
    printStack(stateStack,stateStackTop);
    ifParam = 0;
    //到这里形参的所有所在行就搜罗完毕了
  }
}

(\\)"\042"  {
  //匹配到斜杠引号就不要做任何动作
}


\"  {
  //我们在匹配引号的时候应该保证这个引号是最外层的双引号，而不是单引号中的双引号
  if(singleMark == 1){
    //如果发现这个是单引号中的双引号就忽略不计
  }else {
    printf("匹配到了引号\n");
    BEGIN MARKS;
  }
}

(\\)\'  {
  //如果是转义单引号就忽略不计
}

\'  {
  //匹配到单引号
  printf("匹配到单引号\n");
  if(singleMark == 0) {
    singleMark = 1;
  }else {
    singleMark = 0;
  }
}


[^A-Za-z_]{1}{KEYVARNAME}/[^A-Za-z0-9]{1}  {
  if(ifMain == 1){
    //匹配到一个变量之后看看这个变量我们是不是还关心
    yytext = yytext + 1;
    for(int i = 0 ; i < size ; i++) {
      if(strcmp(yytext , keyName[i])==0){
        //这里得到这个变量所关心的最后一行
        if(yylineno <= keyVarLineCount[i]) {
          //这里匹配到了关键变量
          //关键变量所在的这一行要被保留
          fprintf(yyout,"%d\n",yylineno);
          //此外状态的头部也要保留
          remainLine();
          printStack(stateStack , stateStackTop);
        }
        break;
      }
    }
  }
}





[^A-Za-z0-9]{1}"if"/(" "|\t|\n)*"("  {
  if(ifMain == 1){
    //进入了if语句之后，我们就可以进行压栈操作
    stateStackTop++;
    struct stateNode newstateNode = {STATEIF,{yylineno},nesting,0,0};
    stateStack[stateStackTop] = newstateNode;
    //这里压栈完毕
    //这里定位一开始的我们是不是形参的。
    ifParam = 1;
    addTopLine(&stateStack[stateStackTop],yylineno);
    printStack(stateStack , stateStackTop);
    BEGIN IF;
  }
}

[^A-Za-z0-9]{1}"for"/(" "|\t|\n)*"("  {
  if(ifMain == 1){
    //进入了if语句之后，我们就可以进行压栈操作
    stateStackTop++;
    struct stateNode newstateNode = {STATEFOR,{yylineno},nesting,0,0};
    stateStack[stateStackTop] = newstateNode;
    //这里压栈完毕
    //这里定位一开始的我们是不是形参的。
    ifParam = 1;
    addTopLine(&stateStack[stateStackTop],yylineno);
    printStack(stateStack , stateStackTop);
    BEGIN IF;
  }
}

[^A-Za-z0-9]{1}"while"/(" "|\t|\n)*"("  {

  if(ifMain == 1){
    //这里是直接看到了while，我们进行压栈操作
    stateStackTop++;
    struct stateNode newstateNode = {STATEWHILE,{yylineno},nesting,0,0};
    stateStack[stateStackTop] = newstateNode;
    //这里也需要一个确定形参的变量，因为while的出现一般不会在其他关键词的形参中，所以这个时候ifParam一定是0
    ifParam = 1;
    addTopLine(&stateStack[stateStackTop],yylineno);
    printStack(stateStack , stateStackTop);
    //因为单纯的while和不带else的if是一样的，所以我们可以让while和if进入同一个if状态。
    smallnesting=0;
    BEGIN IF;
  }
}

[^A-Za-z0-9]{1}"do"/(" "|\t|\n)*"{"  {
  if(ifMain == 1){
    //这里是直接看到了do，我们要进行压栈操作
    stateStackTop++;
    struct stateNode newstateNode = {STATEDO,{yylineno},nesting,0,0};
    stateStack[stateStackTop] = newstateNode;

    //DO没有形参，所以我们不用考虑ifParam

    addTopLine(&stateStack[stateStackTop],yylineno);
    printStack(stateStack , stateStackTop);
    //这里我们需要进入一个DO状态
    BEGIN DO;
  }
}

<MAIN>.|\n  {}

<MARKS>(\\)\'  {
  //如果是转义单引号就忽略不计
}





<MARKS>\"  {
  printf("在MARK中匹配到了引号\n");
  //如果我们在匹配上左引号号的时候匹配上右引号
  if(singleMark == 1){
    //如果发现这个是单引号中的双引号就忽略不计
  }else {
    printf("匹配到了引号\n");

    enum STATE nextState = stateStack[stateStackTop].nowstate;

    if(nextState == STATENONE){
      printf("%s\n","回到初始状态");
      BEGIN INITIAL;
    }else
    if(nextState == STATEIF){
      printf("%s\n","回到IF状态");
      BEGIN IF;
    }else
    if(nextState == STATEELSE){
      printf("%s\n","回到ELSE状态");
      BEGIN ELSE;
    }else
    if(nextState == STATEWHILE){
      printf("%s\n","回到WHILE状态");
      BEGIN IF;
    }else
    if(nextState == STATEFOR){
      printf("%s\n","回到FOR状态");
      BEGIN IF;
    }else
    if(nextState == STATEDO){
      printf("%s\n","回到DO状态");
      BEGIN DO;
    }else
    if(nextState == STATEMAIN){
      printf("%s\n","回到MAIN状态");
      BEGIN MAIN;
    }
  }
}

<MARKS>\' {
  //在mark状态下面如果匹配到单引号执行一样的处理
  //匹配到单引号
  printf("匹配到单引号\n");
  if(singleMark == 0) {
    singleMark = 1;
  }else {
    singleMark = 0;
  }
}

<MARKS>(\\)"\042"  {
  //匹配到斜杠引号就不要做任何动作
  printf("在MARK中匹配到了斜杠引号\n");
}

<MARKS>.|\n  {
}


.  {}

\n  {
}

%%
void addTopLine(struct stateNode* node, int lineCount){
  //这个函数的目的就是要把一个状态节点的地址传进来，然后为这个结果体添加更多的头部关建行。
  //首先看看这一行之前有没有登记过，一般就是看看上一行
  if((node->nowindex > 0) && (lineCount != (node->headLine[node->nowindex-1]))){
    node->headLine[node->nowindex] = lineCount;
    node->nowindex++;
  }else if(node->nowindex == 0){
    node->headLine[node->nowindex] = lineCount;
    node->nowindex++;
  }
}

void printStack(struct stateNode* stateStack , int stateStackTop){
  //将栈指针传进来获得一个状态栈的指针，我们来打印整个状态栈
  if(stateStackTop != -1){
    printf("\n\n------------print the stateStack------------\n");
    for(int i = stateStackTop ; i >= 0 ; i--){
      if(stateStack[i].nowstate == STATEIF){
        printf("%s,","IF");
      }else if(stateStack[i].nowstate == STATEELSE){
        printf("%s,","ELSE");
      }else if(stateStack[i].nowstate == STATEFOR){
        printf("%s,","FOR");
      }else if(stateStack[i].nowstate == STATEDO){
        printf("%s,","DO");
      }else if(stateStack[i].nowstate == STATEWHILE){
        printf("%s,","WHILE");
      }else if(stateStack[i].nowstate == STATENONE){
        printf("%s,","NONE");
      }else if(stateStack[i].nowstate == STATEMAIN){
        printf("%s,","MAIN");
      }

      printf("[ ");
      for(int j = 0 ; j < stateStack[i].nowindex ; j++){
        printf("%d ",stateStack[i].headLine[j]);
      }
      printf("], ");
      printf("%d, ",stateStack[i].nownesting);
      printf("%d, ",stateStack[i].nowindex);
      printf("%d\n",stateStack[i].remainHead);
    }

    printf("\n------------print the stateStack------------\n\n");
  }

}

enum STATE exitState(struct stateNode* stateStack , int *stateStackTop){
  //在弹栈之前看看头部是不是应该被保留，MAIN函数的头部直接算成必须保留
  printf("#######%d",*stateStackTop);
  if(stateStack[*stateStackTop].remainHead == 1 || stateStack[*stateStackTop].nowstate==STATEMAIN){
    printf("开始保留状态头部行\n");
    if(stateStack[*stateStackTop].nowindex == 1){
      //如果头部行号只有一行，那就把这一行放到文件中
      fprintf(yyout,"%d\n",stateStack[*stateStackTop].headLine[0]);
    }else if(stateStack[*stateStackTop].nowindex == 2){
      //如果头部行号有多行，这个时候再栈里面给出的是一个范围，我们需要做的就是把这个范围中的所有行号全部放到文件中
      for(int i = stateStack[*stateStackTop].headLine[0] ; i <= stateStack[*stateStackTop].headLine[1] ; i++ ){
        fprintf(yyout,"%d\n",i);
      }
    }
  }


  //我们将栈顶向下挪一个，然后把栈顶的元素删除
  if(stateStackTop > 0){
    (*stateStackTop)--;
    enum STATE returnState = stateStack[(*stateStackTop)].nowstate;
    return returnState;
  }else if((*stateStackTop) == 0){
    (*stateStackTop)--;
    enum STATE returnState = STATENONE;
    return returnState;
  }else {
    printf("出错了！");
    exit(0);
  }
}

void remainLine(){
  //这里将状态栈中的所有remainHead变为1
  for(int i = 0 ; i <= stateStackTop ; i++){
    stateStack[i].remainHead = 1;
  }
}

int main(int argc, char *argv[]){
  ifMain = 0;
  yylineno = 1;
  singleMark = 0;
  stateStackTop = -1;
  nesting = 0;
  smallnesting = 0;
  ifParam = 1;
  /*首先把输入和输出文件规定好*/
  if(argc > 1){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
    if(!(yyout = fopen(argv[2],"w"))){
      //我们返回的文件将会是一系列行号，中间用回车隔开
      perror(argv[2]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");


  yylex();


}
