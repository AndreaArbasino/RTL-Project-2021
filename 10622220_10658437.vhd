library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
entity project_reti_logiche is
 Port (     i_clk : in std_logic;
            i_start : in std_logic;
            i_rst : in std_logic;
            i_data : in std_logic_vector (7 downto 0);
            o_address : out std_logic_vector (15 downto 0);
            o_done : out std_logic;
            o_en : out std_logic;
            o_we : out std_logic;
            o_data : out std_logic_vector (7 downto 0));
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

--Stati per FSM
type state_type is (reset,getcolonne,getrighe,checkzero,prodottodimensione,lettura,maxmin,calcolodelta,calcoloshift,rilettura, sottrazione, calcolotmp, nuovopixel, salva, scorrimento);
signal stato_corrente, stato_prossimo : state_type; 

--Segnali
signal bufferdati: std_logic_vector(7 downto 0); --segnale che memorizza ciò che viene letto dalla memoria
signal min: std_logic_vector(7 downto 0); --segnale per memorizzare il pixel con valore minore
signal max: std_logic_vector(7 downto 0); --segnale per memorizzare il pixel con valore maggiore
signal ncol: std_logic_vector(7 downto 0); --segnale per memorizzare il numero di colonne dell'immagine
signal nrow: std_logic_vector(7 downto 0); --segnale per memorizzare il numero di righe dell'immagine
signal new_pixel: std_logic_vector(7 downto 0); --segnale in cui viene salvato il valore del pixel rielaborato
signal currpixel: std_logic_vector(7 downto 0); --segnale in cui viene salvato il valore del pixel corrente ancora da rielaborare
signal tmp_pixel: std_logic_vector(15 downto 0); --segnale temporaneo utilizzato per calcolare il valore del new_pixel
signal limit_address: std_logic_vector(15 downto 0); --segnale per memorizzare l'ultimo indirizzo di lettura dell'immagine
signal last_address: std_logic_vector(15 downto 0); --segnale per memorizzare l'ultimo indirizzo di scrittura dell'immagine
signal read_address: std_logic_vector(15 downto 0); --segnale utilizzato per scorrere gli indirizzi di lettura
signal write_address: std_logic_vector(15 downto 0); --segnale utilizzato per scorrere gli indirizzi di scrittura
signal dimensione: std_logic_vector(15 downto 0); --segnale in cui viene memorizzato il risultato del calcolo della dimensione dell'immagine
signal delta: integer range 0 to 255; 
signal shift: integer range 0 to 8;
 
begin
	process(i_clk, i_rst)
    begin
		if(i_rst='1') then 
			stato_corrente<=reset;
		elsif(rising_edge(i_clk)) then
			stato_corrente<= stato_prossimo;
		end if;
		if(falling_edge(i_clk)) then
			case stato_corrente is	
				when reset =>
					if(i_start='0') then
						stato_prossimo<= reset;
					else
						--reset per inizializzare al valore di default alcuni segnali 
						o_address<="0000000000000000";
						read_address<="0000000000000000";
						dimensione<="0000000000000000";
						min<="11111111";
						max<="00000000";
						o_en<= '1';
						o_we<= '0';
						o_done<='0';
						stato_prossimo<= getcolonne ;
					end if;		
				when getcolonne =>	
					--salvataggio numero colonne
					ncol<=i_data;
					o_address <= read_address + "0000000000000001";
					read_address<= read_address + "0000000000000001";
					stato_prossimo<= getrighe;
				when getrighe =>	
					--salvataggio numero righe
					nrow<=i_data;
					o_address <= read_address + "0000000000000001";
					read_address<= read_address + "0000000000000001";
					stato_prossimo<= checkzero;
				when checkzero =>
					--se # righe o colonne è pari a 0 (dimensione = 0) allora "termino"	
					o_en<= '0';
					o_we<= '0';
					if ((ncol = "00000000") OR (nrow = "00000000")) then
						o_done<='1';
						o_en<= '0';
						o_we<= '0';
						if(i_start='0') then
							o_done<='0';
							stato_prossimo<= reset;
						else 
							stato_prossimo<= checkzero;
						end if;
					else 
					   stato_prossimo<= prodottodimensione;
					end if;
				when prodottodimensione =>
					--calcolo dimensione foto
					if(ncol = "00000000") then
						limit_address<=read_address + dimensione - "0000000000000001";
						stato_prossimo<=lettura;
					else
						dimensione<= dimensione+("00000000" & nrow);
						ncol<= ncol - "00000001";
						stato_prossimo<= prodottodimensione;
					end if;	
				when lettura =>	
					--ciclo di lettura dei pixel
					o_en<= '1';
					o_we<= '0';
					bufferdati<= i_data;
					o_address <= read_address + "0000000000000001";
					read_address<= read_address + "0000000000000001";
					stato_prossimo<= maxmin;	
				when maxmin =>	
					--valutazione massimo e minimo
					o_en<= '0';
					o_we<= '0';
				    if(bufferdati<=min) then
							min<=bufferdati;
					end if;
					if(bufferdati>=max) then
							max<=bufferdati;
					end if;
					if(read_address>limit_address) then
						o_address<= "0000000000000010";
						stato_prossimo<= calcolodelta;
					else
					   stato_prossimo<= lettura;
					end if;   
				when calcolodelta =>	
					--calcolo del delta e dell'ultimo indirizzo di scrittura
					delta<=to_integer(unsigned(max))-to_integer(unsigned(min));
					last_address <= read_address  + dimensione - "0000000000000001";
					stato_prossimo<= calcoloshift;
				when calcoloshift =>	
					--pseudo calcolo dello shift con un case e reset dell'indirizzo di lettura
					case delta is	
						when 0 =>
							shift<= 8;
						when 1 to 2 =>
							shift<=7;
						when 3 to 6=>
							shift<=6;
						when 7 to 14  =>
							shift<=5;
						when 15 to 30 =>
							shift<=4;
						when 31 to 62 =>
							shift<=3;
						when 63 to 126 =>
							shift<=2;
						when 127 to 254 =>
							shift<=1;
						when others =>
							shift<=0;
					end case;	
					read_address<= "0000000000000010";
					tmp_pixel<= "0000000000000000";
					write_address<=limit_address + "0000000000000001";
					stato_prossimo<= rilettura;
					o_en<= '1';
					o_we<= '0';
				when rilettura =>	
					--stato di lettura per poter modificare l'immagine
					o_en<= '1';
					o_we<= '0';
					currpixel<=i_data;
					read_address<= read_address + "0000000000000001";
					stato_prossimo<= sottrazione;
				when sottrazione =>
					o_en<= '0';
					o_we<= '0';
					bufferdati<= std_logic_vector(unsigned(currpixel) - unsigned(min));
					stato_prossimo<= calcolotmp;
				when calcolotmp =>	
					--calcolo del tmp pixel
					tmp_pixel <= std_logic_vector(shift_left(unsigned("00000000" & bufferdati), shift));
					o_address<=write_address;
					stato_prossimo<= nuovopixel;
				when nuovopixel =>	
					--scelta del nuovo pixel
					if(tmp_pixel<"0000000011111111") then
						new_pixel<= tmp_pixel(7 downto 0);
					else
						new_pixel<="11111111";
					end if;
					stato_prossimo<= salva;
				when salva =>
					if(write_address>=last_address) then --gestione dei segnali per terminare la computazione
						o_done<='1';
						o_en<= '1';
						o_we<= '1';
						o_data<= new_pixel;
						if(i_start='0') then
							o_we<= '0';
							o_en<= '0';
							o_done<='0';
							stato_prossimo<= reset;
						else	
							stato_prossimo<=salva;
						end if;
					else --salvataggio al giusto indirizzo
						o_en<= '1';
						o_we<= '1';
						o_done<='0';
						o_data<= new_pixel;
						stato_prossimo<= scorrimento;
					end if;	
				when scorrimento =>
					--stato che si occupa di far scorrere gli indirizzi di lettura e scrittura
				    o_en<= '1';
					o_we<= '0';
				    write_address<= write_address + "0000000000000001";
					o_address<= read_address;	
					stato_prossimo<= rilettura;	
				when others => o_done <= '0';  
			end case;
        end if;
	end process;
end Behavioral;
					